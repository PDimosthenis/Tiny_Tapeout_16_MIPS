import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer


def as_u16_from_outputs(dut) -> int:
    return (int(dut.uio_out.value) << 8) | int(dut.uo_out.value)


async def load_instr(dut, addr: int, instr: int) -> None:
    # Verilog: @(negedge clk);
    # Drive controls/data before the write edge to avoid race conditions.
    await FallingEdge(dut.clk)
    # Verilog: ui_in = {1'b0, 1'b0, 3'b000, addr};
    dut.ui_in.value = addr & 0x7
    # Verilog: uio_in = instr[7:0];
    dut.uio_in.value = instr & 0xFF
    # Verilog: @(posedge clk);
    await RisingEdge(dut.clk)

    # Verilog: @(negedge clk);
    await FallingEdge(dut.clk)
    # Verilog: ui_in = {1'b0, 1'b1, 3'b000, addr};
    dut.ui_in.value = 0x40 | (addr & 0x7)
    # Verilog: uio_in = instr[15:8];
    dut.uio_in.value = (instr >> 8) & 0xFF
    # Verilog: @(posedge clk);
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_behavior_matches_verilog_tb(dut):
    """Mirror the behavioral checks from test/tb.v using cocotb."""
    # Verilog: initial clk=0; always #50 clk=~clk;
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())

    # Verilog init block assignments.
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Verilog: repeat (4) @(posedge clk);
    await ClockCycles(dut.clk, 4)
    # Verilog: rst_n = 1; ena = 1;
    dut.rst_n.value = 1
    dut.ena.value = 1

    program = [
        0x6101,  # addi r1, r0, 1
        0x6202,  # addi r2, r0, 2
        0x6303,  # addi r3, r0, 3
        0x6501,  # addi r1, r1, 1
        0x6A01,  # addi r2, r2, 1
        0x6F01,  # addi r3, r3, 1
        0x7006,  # jump 6
        0x6109,  # addi r1, r0, 9 (should never execute)
    ]

    for addr, instr in enumerate(program):
        # Verilog: load_instr(addr, instr);
        await load_instr(dut, addr, instr)

    # Verilog: #1;
    await Timer(1, units="ns")

    for addr, exp in enumerate(program):
        # Verilog: check_loaded_instr(addr, exp);
        got = int(dut.cpu.inst_mem.ram[addr].value)
        assert got == exp, f"RAM[{addr}] mismatch: got 0x{got:04X}, exp 0x{exp:04X}"

    # Verilog: check_u8(uio_oe, 8'h00, "uio_oe in load mode");
    assert int(dut.uio_oe.value) == 0x00, "uio_oe must be 0x00 in load mode"

    # Verilog: ui_in = 8'h80; uio_in = 8'h00;
    dut.ui_in.value = 0x80  # run mode
    dut.uio_in.value = 0x00
    # Verilog: @(negedge clk);
    await FallingEdge(dut.clk)
    # Verilog: check_u8(uio_oe, 8'hFF, "uio_oe in run mode");
    assert int(dut.uio_oe.value) == 0xFF, "uio_oe must be 0xFF in run mode"

    expected_steps = [
        (0, 0x0001),
        (1, 0x0002),
        (2, 0x0003),
        (3, 0x0002),
        (4, 0x0003),
        (5, 0x0004),
        (6, 0x0000),
        (6, 0x0000),
    ]

    for exp_pc, exp_alu in expected_steps:
        # Verilog run_and_step task:
        #   #1; check PC/ALU; @(posedge clk);
        await Timer(1, units="ns")
        got_pc = int(dut.cpu.pc_out.value)
        got_alu = as_u16_from_outputs(dut)
        assert got_pc == exp_pc, f"PC mismatch: got {got_pc}, exp {exp_pc}"
        assert got_alu == exp_alu, f"ALU mismatch: got 0x{got_alu:04X}, exp 0x{exp_alu:04X}"
        await RisingEdge(dut.clk)

    # Verilog: #1; then final register checks.
    await Timer(1, units="ns")
    r1 = int(dut.cpu.rf.registers[1].value)
    r2 = int(dut.cpu.rf.registers[2].value)
    r3 = int(dut.cpu.rf.registers[3].value)

    assert r1 == 0x0002, f"r1 mismatch: got 0x{r1:04X}, exp 0x0002"
    assert r2 == 0x0003, f"r2 mismatch: got 0x{r2:04X}, exp 0x0003"
    assert r3 == 0x0004, f"r3 mismatch: got 0x{r3:04X}, exp 0x0004"