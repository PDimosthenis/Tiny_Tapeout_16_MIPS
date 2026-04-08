![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# 16-bit MIPS Single-Cycle Processor

A complete 16-bit MIPS single-cycle processor implemented in Verilog for Tiny Tapeout, designed to load 16-bit instructions through 8-bit Tiny Tapeout input pins.

- [Read the documentation for project](docs/info.md)

## Overview

This project implements a simplified 16-bit MIPS processor using a single-cycle architecture. The processor is optimized for Tiny Tapeout constraints and operates at 10 MHz. It features a complete datapath including instruction memory, register file, ALU, control unit, and data memory.

## Key Features

- **16-bit Architecture**: Full 16-bit instruction and data paths
- **Single-Cycle Design**: All operations complete in a single clock cycle
- **Dual-Mode Operation**:
  - **Load Mode**: Load 16-bit instructions via two 8-bit writes
  - **Run Mode**: Execute loaded instructions
- **8 Instructions Supported**: add, sub, xor, or, lw, sw, addi, jump
- **4-Entry Register File**: 2-bit addressing allows 4 general-purpose registers
- **4-Entry Data Memory**: 2-bit addressing for 4 memory locations
- **Program Counter**: 4-bit counter supporting up to 8 instruction locations

## Architecture

### Core Components

1. **Program Counter (PC)**: 4-bit counter with jump support
2. **Instruction Memory**: 8 x 16-bit ROM for storing program instructions
3. **Register File**: 4 x 16-bit general-purpose registers
4. **ALU (Arithmetic Logic Unit)**: Supports ADD, SUB, OR, XOR operations
5. **Control Unit**: Decodes opcode and generates control signals
6. **Data Memory**: 4 x 16-bit RAM for load/store operations
7. **Decoder**: Extracts register addresses and immediates from instructions

### Instruction Encoding

Instructions are 16 bits wide with the following formats:

**R-Type (Arithmetic):**
```
Bits [15:12] | [11:8]  | [7:4] | [3:0]
Opcode       | rs      | rt    | rd
```

**I-Type (Immediate):**
```
Bits [15:12] | [11:8]  | [7:4] | [3:0]
Opcode       | rs      | rt    | Immediate(4-bit)
```

**Jump-Type:**
```
Bits [15:12] | [11:4]  | [3:0]
Opcode       | Unused  | Target Address
```

### Supported Instructions

| Opcode | Instruction | Type | Operation |
|--------|-------------|------|-----------|
| 0000   | add         | R    | rd ← rs + rt |
| 0001   | sub         | R    | rd ← rs - rt |
| 0010   | xor         | R    | rd ← rs ^ rt |
| 0011   | or          | R    | rd ← rs \| rt |
| 0100   | lw          | I    | rt ← Mem[rs + imm] |
| 0101   | sw          | I    | Mem[rs + imm] ← rt |
| 0110   | addi        | I    | rt ← rs + sign_ext(imm) |
| 0111   | jump        | J    | PC ← jump_addr |

## Pin Configuration

### Inputs (ui[7:0]) - Instruction Byte During Load Mode

| Pin | Signal | Description |
|-----|--------|-------------|
| ui[0:5] | Data[5:0] | Instruction byte bits |
| ui[6] | Byte Select | 0 = load low byte, 1 = load high byte |
| ui[7] | Mode | 0 = load mode, 1 = run mode |

### Outputs (uo[7:0])

| Pin | Signal | Description |
|-----|--------|-------------|
| uo[7:0] | ALU_out[7:0] | Lower 8 bits of ALU result (in run mode) |
| uo[7:0] | ui_in echo | Echoes input data (in load mode) |

### Bidirectional (uio[7:0])

| Pin | Signal | Description |
|-----|--------|-------------|
| uio[0:3] | PC[3:0] | Program counter output (in run mode) |
| uio[4:5] | Unused | Not used |
| uio[6] | Byte Select | 0 = low byte, 1 = high byte (load mode input) |
| uio[7] | Mode | 0 = load mode, 1 = run mode (input) |

## Operation Modes

### Load Mode (ui[7] = 0)

1. Send first byte (low 8 bits) of instruction via ui[7:0]
2. Set ui[6] = 0 to indicate low byte
3. Toggle ena after each byte
4. Send second byte (high 8 bits) of instruction
5. Set ui[6] = 1 to indicate high byte
6. Toggle ena
7. Output on uo shows echoed ui value for verification

### Run Mode (ui[7] = 1)

1. Processor automatically increments PC after each cycle
2. Fetches instruction from memory at PC location
3. Executes instruction
4. ALU result appears on uo[7:0]
5. Current PC appears on uio[3:0]

## Testing

Comprehensive testbenches are provided in the `test/` directory:

- [test/tb.v](test/tb.v) - Main testbench
- [test/test.py](test/test.py) - Python test script
- [test/README.md](test/README.md) - Testing documentation

To run tests:
```bash
cd test/
make
```

## Design Specifications

- **Technology**: Universal (optimized for Tiny Tapeout)
- **Clock Frequency**: 10 MHz
- **Tiles Required**: 1x1
- **Language**: Verilog
- **Top Module**: `tt_um_kishorenetheti_tt8_mips`

## Resources

- [Tiny Tapeout](https://tinytapeout.com)
- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [MIPS Instruction Set Documentation](https://www.chipverify.com/tutorials/mips)
- [Join the community](https://tinytapeout.com/discord)

## Author

Designed by Kishore Netheti for Tiny Tapeout.
