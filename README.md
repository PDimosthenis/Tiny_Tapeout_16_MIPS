![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

## Design Summary

This project implements a small 16-bit MIPS-like single-cycle CPU for Tiny Tapeout. The RTL in [src/project.v](src/project.v) uses a load/run interface on the Tiny Tapeout pins and exposes the ALU result on the output pins.

## How It Works

The top module, [tt_um_top_module_16_mips](src/project.v), uses `ui_in[7]` as the mode select bit. When `ui_in[7] = 0`, the design is in load mode and instruction bytes are written into instruction memory one halfword at a time. `ui_in[6]` selects the low byte or high byte, `ui_in[2:0]` selects the instruction address, and `uio_in[7:0]` carries the instruction byte. The unused input pins (ui_in[5:3]) are intentionally driven to zero using a reduction AND operation. This ensures they are not left floating and prevents related synthesis warnings.

When `ui_in[7] = 1`, the design enters run mode. The program counter advances on each clock edge, the decoder extracts the register fields and immediate values, the control unit generates the datapath control signals, and the ALU executes arithmetic, logic, and address calculations. In run mode, `uo_out[7:0]` shows the low byte of the ALU result and `uio_out[7:0]` shows the high byte, so the full result is `{uio_out, uo_out}`.

The register file has four architectural registers addressed by 2-bit fields. The data memory in the RTL is 2 words deep, so the design is compact enough to fit Tiny Tapeout constraints while still demonstrating arithmetic, memory access, and jump control flow.

## Supported Instructions

The processor supports these opcodes:

| Opcode | Instruction | Behavior |
|--------|-------------|----------|
| 0000   | add         | `rd = rs + rt` |
| 0001   | sub         | `rd = rs - rt` |
| 0010   | xor         | `rd = rs ^ rt` |
| 0011   | or          | `rd = rs | rt` |
| 0100   | lw          | `rt = Mem[rs + imm]` |
| 0101   | sw          | `Mem[rs + imm] = rt` |
| 0110   | addi        | `rt = rs + sign_ext(imm)` |
| 0111   | jump        | `PC = jump_addr` |

## Instruction Format

Instructions are 16 bits wide.

R-type:
`[15:12] opcode | [11:10] rs | [9:8] rt | [7:6] rd | [5:0] unused`

I-type:
`[15:12] opcode | [11:10] rs | [9:8] rt | [7:0] imm`

Jump:
`[15:12] opcode | [11:3] unused | [2:0] target`

## Tiny Tapeout Interface

### Inputs

- `ui_in[7]`: mode select, `0` = load, `1` = run
- `ui_in[6]`: byte select, `0` = low byte, `1` = high byte
- `ui_in[2:0]`: instruction address during load mode
- `uio_in[7:0]`: instruction byte during load mode

### Outputs

- `uo_out[7:0]`: lower 8 bits of the ALU result in run mode, or the load-mode echo of `uio_in[7:0]`
- `uio_out[7:0]`: upper 8 bits of the ALU result in run mode
- `uio_oe[7:0]`: `8'h00` in load mode, `8'hFF` in run mode

### Mode Behavior

Load mode:
1. Set `ui_in[7] = 0`.
2. Select an instruction address on `ui_in[2:0]`.
3. Write the low byte on `uio_in[7:0]` with `ui_in[6] = 0`.
4. Write the high byte on `uio_in[7:0]` with `ui_in[6] = 1`.
5. Set `ui_in[7] = 1` to enter run mode.

Run mode:
1. The CPU fetches from instruction memory using the program counter.
2. The datapath executes one instruction per cycle.
3. `uo_out` and `uio_out` together show the full 16-bit ALU result.

## External Hardware

The design does not require external peripherals to run. The required external signals are:

- `clk`: system clock input, intended for 10 MHz operation.
- `rst_n`: active-low reset input.
- `ena`: tile enable input.
- `ui_in[7:0]`: Tiny Tapeout control pins for mode, byte select, and instruction address.
- `uio_in[7:0]`: instruction byte input during load mode.
- `uo_out[7:0]`: ALU result low byte.
- `uio_out[7:0]`: ALU result high byte.

No extra RAM, ROM, or UART is needed because the design contains its own instruction memory and data memory internally.

## Files

- [src/project.v](src/project.v) contains the full hardware design.
- [test/tb.v](test/tb.v) is the Verilog behavioral testbench used for simulation.
- [test/test.py](test/test.py) is the cocotb test that mirrors the Verilog testbench.

## Testing

Local simulation uses cocotb through the `test/Makefile` setup.

The testbench and cocotb test both:

1. Load a short instruction program into instruction memory.
2. Verify the load-mode memory contents.
3. Switch into run mode.
4. Check the PC, ALU result, and register state cycle by cycle.

```bash
cd test
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
make
```

If you only want to run the testbench, use `make` from the `test/` directory. GitHub Actions uses the same flow in `.github/workflows/test.yaml`.

## Design Data

- Clock frequency: 10 MHz
- Tile size: 1x1
- Top module: `tt_um_top_module_16_mips`
- Language: Verilog

## Configuration Update

- Updated `src/config.json`: `PL_TARGET_DENSITY_PCT` was increased from `60` to `80`.
- This aligns with Tiny Tapeout guidance for cases where global placement can fail at lower density targets.

## Author

Dimosthenis Papathanasiou, Andreas Skoufakis , Christoforos Marinopoulos
