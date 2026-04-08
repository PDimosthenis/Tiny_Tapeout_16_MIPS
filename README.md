![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# 16-bit MIPS Single Cycle Processor

This project is a Tiny Tapeout 16-bit MIPS-like single-cycle CPU written in Verilog. It loads 16-bit instructions through the 8-bit `uio_in` input and exposes the ALU result on the Tiny Tapeout output pins.

- [Project documentation](docs/info.md)

## Overview

The design implements a compact single-cycle datapath with a 4-entry register file, 4-word data memory, instruction memory, decoder, control unit, ALU, and 4-bit program counter. It is optimized for the Tiny Tapeout I/O constraints and runs at 10 MHz.

## How It Works

The core is a single-cycle processor, so each instruction is fetched, decoded, executed, and written back in one clock cycle. The instruction memory stores 16-bit words, but the Tiny Tapeout input pins are only 8 bits wide, so instructions are loaded in two steps: low byte first, then high byte. The `ui_in[7]` pin selects load mode or run mode, and `ui_in[6]` selects which byte of the instruction word is being written.

During run mode, the program counter selects the next instruction, the decoder extracts the register fields and immediate, the control unit generates the datapath signals, and the ALU either performs arithmetic/logic or calculates addresses for load and store operations. The lower 8 bits of the ALU result are shown on `uo_out`, and the low 4 bits of the program counter are shown on `uio_out`.

The design uses only four architectural registers and two memory locations. That keeps the datapath small enough for Tiny Tapeout while still demonstrating a complete MIPS-style control flow with arithmetic, memory access, and jump behavior.

## Supported Instructions

The processor supports eight opcodes:

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

- `uo_out[7:0]`: lower 8 bits of the ALU result in run mode, or `uio_in[7:0]` in load mode
- `uio_out[7:0]`: upper 8 bits of the ALU result in run mode
- `uio_oe[7:0]`: `8'h00` in load mode, `8'hFF` in run mode

### Mode Behavior

Load mode:
1. Set `ui_in[7] = 0` for load mode
2. Select an instruction address on `ui_in[2:0]`
3. Write the low byte on `uio_in[7:0]` with `ui_in[6] = 0`
4. Write the high byte on `uio_in[7:0]` with `ui_in[6] = 1`
5. Set `ui_in[7] = 1` to enter run mode

Run mode:
1. The CPU fetches from instruction memory using the program counter
2. The datapath executes one instruction per cycle
3. `uo_out` and `uio_out` together show the full 16-bit ALU result (`{uio_out, uo_out}`)

## External Hardware

The design does not require external peripherals to run, but the Tiny Tapeout pins are used as the external interface:

- `clk` is the system clock input and should be driven at 10 MHz for normal operation.
- `rst_n` is an active-low reset input.
- `ena` enables the tile.
- `ui_in[7]` selects load mode or run mode.
- `ui_in[6]` selects low-byte or high-byte writes during instruction loading.
- `ui_in[2:0]` selects the instruction address during load mode.
- `uio_in[7:0]` is the 8-bit instruction byte input during load mode.
- `uo_out[7:0]` exposes ALU result bits `[7:0]` in run mode.
- `uio_out[7:0]` exposes ALU result bits `[15:8]` in run mode.

If you are wiring this to test equipment or a board, the only required external signals are clock, reset, enable, and the Tiny Tapeout pin group. No extra RAM, ROM, or UART is needed because the design carries its own instruction memory and data memory internally.

## Files

- [src/project.v](src/project.v) contains the full hardware design
- [test/tb.v](test/tb.v) is the Verilog testbench used for simulation
- [test/test.py](test/test.py) is the cocotb test file used by GitHub Actions and local verification

## Testing

Local simulation uses cocotb through the `test/Makefile` setup.

The testbench performs two main checks:

1. It exercises reset and basic signal behavior.
2. It verifies the processor interface can be simulated cleanly through cocotb on GitHub Actions and locally.

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

## Author

Dimosthenis Papathanasiou, Andreas Skoufakis
