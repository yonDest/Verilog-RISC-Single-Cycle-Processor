# RISC-V Single-Cycle Processor — Verilog RTL Implementation

A fully functional 32-bit RISC-V (RV32I) single-cycle processor implemented in synthesizable Verilog. The design covers the complete datapath and control path — from instruction fetch through writeback — and executes a representative subset of the RISC-V base integer ISA including arithmetic, logic, memory, branch, and jump instructions.

---

## Table of Contents

- [Overview](#overview)
- [Supported ISA](#supported-isa)
- [Architecture](#architecture)
- [Module Breakdown](#module-breakdown)
- [Datapath Signal Flow](#datapath-signal-flow)
- [File Structure](#file-structure)
- [Simulation & Getting Started](#simulation--getting-started)
- [Design Decisions & Notes](#design-decisions--notes)

---

## Overview

| Property | Value |
|---|---|
| ISA | RISC-V RV32I (subset) |
| Architecture | Single-cycle |
| Register Width | 32-bit (64-bit ALU datapath) |
| Register File | 32 × 32-bit general-purpose registers |
| Instruction Memory | 512 × 32-bit word-addressable ROM |
| Data Memory | 512 × 32-bit word-addressable RAM |
| HDL | Verilog (IEEE 1364-2001 / SystemVerilog-compatible) |
| Instruction Types | R, I, S, B, J (JAL/JALR) |

---

## Supported ISA

### R-Type (register–register)
| Instruction | Operation |
|---|---|
| `ADD` | rd = rs1 + rs2 |
| `SUB` | rd = rs1 − rs2 |
| `AND` | rd = rs1 & rs2 |
| `OR` | rd = rs1 \| rs2 |
| `XOR` | rd = rs1 ^ rs2 |
| `SLL` | rd = rs1 << rs2 |
| `SRL` | rd = rs1 >> rs2 (logical) |
| `SRA` | rd = rs1 >>> rs2 (arithmetic) |
| `SLT` | rd = (rs1 < rs2) signed |
| `SLTU` | rd = (rs1 < rs2) unsigned |

### I-Type (immediate / load)
| Instruction | Operation |
|---|---|
| `ADDI` | rd = rs1 + imm |
| `ANDI` | rd = rs1 & imm |
| `ORI` | rd = rs1 \| imm |
| `XORI` | rd = rs1 ^ imm |
| `SLLI` | rd = rs1 << imm |
| `SRLI` | rd = rs1 >> imm (logical) |
| `SRAI` | rd = rs1 >>> imm (arithmetic) |
| `SLTI` | rd = (rs1 < imm) signed |
| `SLTIU` | rd = (rs1 < imm) unsigned |
| `LW` | rd = Mem[rs1 + imm] |

### B-Type (branch)
| Instruction | Operation |
|---|---|
| `BEQ` | if rs1 == rs2, PC += imm<<1 |

### J-Type (jump)
| Instruction | Operation |
|---|---|
| `JAL` | rd = PC+4; PC = PC + imm<<1 |
| `JALR` | rd = PC+4; PC = rs1 + imm |

---

## Architecture

```
                          ┌───────────────────────────────────────────────────────┐
                          │                    ARCHITECTURE                        │
                          │                                                         │
  ┌────────┐   PC    ┌────┴─────────┐   RD[31:0]   ┌────────────────┐             │
  │   PC   │────────►│ Instruction  │──────────────►│ Main Controller│             │
  │Counter │         │   Memory     │               │  (Opcode→ctrl) │             │
  └────────┘         └─────────────┘               └────────┬───────┘             │
       ▲                    │                                │ Control Signals       │
       │                    │ RD[31:0]                       │ ALUSrc,MemtoReg,      │
  ┌────┴────┐               │                                │ RegWrite,MemRead,     │
  │  MUX    │◄──────────────│──────────── Branch/Jump        │ MemWrite,Branch,      │
  │(PC Sel) │               │             address            │ Jump,ALUop,Asel       │
  └────┬────┘               ▼                                │                       │
       │              ┌─────────────┐                        │                       │
  ┌────┴────┐         │  Register   │◄───── RegWrite ────────┘                       │
  │  Adder  │         │    File     │                                                │
  │  PC+4   │         │ (32×32-bit) │                                                │
  └─────────┘         └──────┬──────┘                                               │
                        RD1  │  RD2                                                  │
                             │                                                        │
                    ┌────────▼────────┐       ┌─────────────┐    ┌──────────────┐   │
                    │   MUX (Asel)    │       │  Immediate  │    │ ALU Control  │   │
                    │  RD1 or PC      │       │  Generation │    │ (funct3/7)   │   │
                    └────────┬────────┘       └──────┬──────┘    └──────┬───────┘   │
                             │                        │                   │           │
                    sign-ext │              ┌─────────▼──────┐           │           │
                    to 64b   │              │  MUX (ALUSrc)  │           │           │
                             │              │  RD2 or imm    │           │           │
                             │              └────────┬───────┘           │           │
                             │                       │                   │           │
                             └──────────► ┌──────────▼──────────────────▼──┐        │
                                          │             ALU                 │        │
                                          │  (64-bit: AND,OR,ADD,SUB,      │        │
                                          │   SLL,SLT,SLTU,XOR,SRL,SRA)   │        │
                                          └──────────────┬─────────────────┘        │
                                                  ALUOut │  Zero flag                │
                                                         │                           │
                                               ┌─────────▼──────┐                   │
                                               │  Data Memory   │                   │
                                               │  (Read/Write)  │                   │
                                               └─────────┬──────┘                   │
                                                         │                           │
                                               ┌─────────▼──────┐                   │
                                               │  MUX1 (3-way)  │ ◄── MemtoReg     │
                                               │ ALUOut/DataOut/ │                   │
                                               │    PC+4         │                   │
                                               └─────────┬──────┘                   │
                                                         │                           │
                                                    WriteData → Register File        │
                                                                                     │
                          └───────────────────────────────────────────────────────┘
```

---

## Module Breakdown

### `architecture.v` — Top-Level Datapath
Instantiates and wires all submodules. Routes control signals from the main controller to every datapath component. Handles the branch/jump PC selection logic using a two-stage MUX chain: one for branch (gated by `BEQ AND Zero`), one for jump (`JAL`/`JALR`).

### `mainController.v` — Main Control Unit
Decodes the 7-bit opcode into 9 control signals:

| Signal | Purpose |
|---|---|
| `ALUSrc` | Selects ALU second operand: register vs. immediate |
| `MemtoReg[1:0]` | Selects writeback source: ALU result, memory, or PC+4 |
| `RegWrite` | Enables register file write |
| `MemRead` | Enables data memory read |
| `MemWrite` | Enables data memory write |
| `Branch` | Enables branch condition evaluation |
| `Jump` | Overrides PC with jump target |
| `ALUop[1:0]` | Encodes instruction class for ALU control |
| `Asel` | Selects ALU first operand: rs1 vs. PC (for JAL/JALR) |

### `ALUControl.v` — ALU Control Decoder
Translates the 2-bit `ALUop` + `funct7[30]` + `funct3[2:0]` fields into a 4-bit ALU control word covering all 10 ALU operations.

### `ALU.v` — Arithmetic Logic Unit
Parameterized 64-bit ALU supporting:
`AND`, `OR`, `ADD`, `SUB`, `SLL`, `SLT` (signed), `SLTU` (unsigned), `XOR`, `SRL`, `SRA`

Outputs a `zero` flag used by the branch logic.

### `Registerfile.v` — Register File
32 × 32-bit register file. Register `x0` is hardwired to zero (read returns 0 regardless of write). Synchronous write on positive clock edge; asynchronous read.

### `InstructionMemory.v` — Instruction ROM
Word-addressed (by byte address), 512-entry ROM pre-loaded with a test program covering all implemented instruction types. Can be extended with `$readmemh` for external program loading.

### `DataMemory.v` — Data RAM
512 × 32-bit word-addressed RAM. Supports combinational read (`MemRead`) and synchronous write (`MemWrite`). Pre-loaded with values `0x00–0x07` for simulation.

### `ImmediateGeneration.v` — Immediate Generator
Extracts and sign-extends immediates for all supported format types:
- **I-type**: 12-bit sign-extended
- **S-type**: split across `inst[31:25]` and `inst[11:7]`
- **B-type**: scrambled bit pattern reassembled and sign-extended
- **J-type (JAL)**: 20-bit immediate with non-contiguous bit layout

### `PCCounter.v` — Program Counter
Synchronous register updated on each positive clock edge with the next PC value selected by the datapath MUXes.

### `MUX.v` — 2-to-1 Multiplexer
Parameterized 2-to-1 MUX used for: ALUSrc, Branch/Jump PC selection, and ALU first-operand selection (`Asel`).

### `MUX1.v` — 3-to-1 Multiplexer
Parameterized 3-to-1 MUX for the writeback stage — selects between ALU result, memory read data, or PC+4 (for JAL/JALR link register write).

### `Adder.v` — PC+4 Adder
Dedicated combinational adder that computes `PC + 4` for the sequential program counter update.

### `add.v` — Branch Target Adder
General-purpose combinational adder used for computing the branch target address: `PC + (imm << 1)`.

### `shift.v` — Immediate Left-Shift
Left-shifts the sign-extended immediate by 1 bit to produce the branch offset (RISC-V branch immediates encode the offset in units of 2 bytes).

---

## Datapath Signal Flow

```
Fetch    →  PC → InstructionMemory → RD[31:0]
Decode   →  RD → MainController (control signals)
         →  RD → RegisterFile (rs1, rs2 read)
         →  RD → ImmediateGeneration (sign-extended imm)
         →  RD → ALUControl (funct3, funct7)
Execute  →  MUX(Asel): rs1 or PC → sign-extend → ALU input A
         →  MUX(ALUSrc): rs2 or imm → ALU input B
         →  ALU → ALUOut, Zero
         →  Branch: Zero AND Branch → branchaddress MUX
         →  Jump: MUX(jump) → PCinput
Memory   →  DataMemory(ALUOut, RD2) → DataOutput
Writeback → MUX1(MemtoReg): ALUOut | DataOutput | PC+4 → Writedata → RegisterFile
```

---

## File Structure

```
.
├── architecture.v         # Top-level datapath integration
├── mainController.v       # Opcode → control signal decoder
├── ALUControl.v           # funct3/funct7 → ALU operation decoder
├── ALU.v                  # 64-bit parameterized ALU
├── Registerfile.v         # 32×32-bit general-purpose register file
├── InstructionMemory.v    # Word-addressed instruction ROM (512 entries)
├── DataMemory.v           # Word-addressed data RAM (512 entries)
├── ImmediateGeneration.v  # Multi-format immediate sign-extension
├── PCCounter.v            # Program counter register
├── MUX.v                  # Parameterized 2-to-1 MUX
├── MUX1.v                 # Parameterized 3-to-1 MUX (writeback select)
├── Adder.v                # PC+4 combinational adder
├── add.v                  # Branch target adder
└── shift.v                # 1-bit left shift for branch offset
```

---

## Simulation & Getting Started

### Prerequisites
- [Icarus Verilog](http://iverilog.icarus.com/) (open-source), **or**
- Xilinx Vivado / Intel Quartus / ModelSim

### Compile & Simulate (Icarus Verilog)

```bash
# Compile all modules with the top-level as the root
iverilog -o processor.vvp architecture.v ALU.v ALUControl.v mainController.v \
         Registerfile.v InstructionMemory.v DataMemory.v ImmediateGeneration.v \
         PCCounter.v MUX.v MUX1.v Adder.v add.v shift.v

# Run the simulation
vvp processor.vvp
```

> **Note:** A testbench module that drives `clk` and monitors register/memory state is recommended for full validation. The instruction memory is pre-loaded with a test program exercising all supported instruction types.

### Pre-Loaded Test Program

The instruction memory contains the following program sequence for smoke-testing the datapath:

| Address | Encoding | Instruction | Notes |
|---|---|---|---|
| 0x00 | `002081B3` | `add x3, x1, x2` | R-type |
| 0x04 | `403202B3` | `sub x5, x4, x3` | R-type |
| 0x08 | `00308383` | `lw x7, 3(x1)` | Load word |
| 0x0C | `0013F333` | `and x6, x7, x1` | R-type |
| 0x10 | `001112B3` | `sll x5, x2, x1` | Shift left |
| 0x14 | `001122B3` | `slt x5, x2, x1` | Set less than |
| 0x18 | `00210463` | `beq x2, x2, 4` | Branch equal |
| 0x1C | `001132B3` | `sltu x5, x2, x1` | Unsigned SLT |
| 0x20 | `001142B3` | `xor x5, x2, x1` | XOR |
| 0x24 | `001152B3` | `srl x5, x2, x1` | Shift right logical |
| 0x28 | `401152B3` | `sra x5, x2, x1` | Shift right arithmetic |
| 0x2C | `008002EF` | `jal x5, 8` | Jump and link |
| 0x30 | `00110293` | `addi x5, x2, 1` | Immediate add |
| 0x34 | `00312293` | `slti x5, x2, 3` | Immediate SLT |
| 0x38 | `00517293` | `andi x5, x2, 5` | Immediate AND |
| 0x3C | `00211293` | `slli x5, x2, 2` | Immediate shift left |
| 0x40 | `002102E7` | `jalr x5, x2, 2` | Jump and link register |

---

## Design Decisions & Notes

**Single-cycle trade-offs.** Every instruction completes in one clock cycle, simplifying control logic at the cost of cycle time being constrained by the longest path (typically a load instruction traversing fetch → decode → ALU → memory → writeback).

**64-bit ALU with 32-bit architecture.** The ALU operates on 64-bit operands internally. The 32-bit register values are sign-extended to 64 bits before entering the ALU, matching the behavior needed for correct arithmetic on signed quantities.

**3-to-1 writeback MUX.** Rather than a two-stage 2-to-1 MUX, a single `MUX1` selects among ALU result, memory data, and `PC+4` in one level of logic. This cleanly supports the JAL/JALR link-register write without extra pipeline-style steering logic.

**Parameterized modules.** `ALU`, `MUX`, `MUX1`, `RegisterFile`, `InstructionMemory`, `DataMemory`, `PCCounter`, `Adder`, `add`, and `shift` are all width-parameterized, making the design adaptable for different data widths without structural changes.

**Immediate generation correctness.** The B-type and J-type immediate formats in RISC-V deliberately scramble bit positions to minimize hardware cost in pipelined implementations. This design faithfully reconstructs these immediates from their non-contiguous bit fields.

**Branch offset scaling.** A dedicated `shift` module left-shifts the sign-extended immediate by 1 before the branch adder, correctly implementing RISC-V's 2-byte-aligned branch encoding where the LSB of the offset is always implied to be 0.

---

## Potential Extensions

- **Pipelined version** — Add IF/ID, ID/EX, EX/MEM, MEM/WB pipeline registers with hazard detection and forwarding logic.
- **Testbench** — Add a self-checking testbench with `$monitor` / `$dumpvars` for waveform viewing in GTKWave.
- **`$readmemh` program loading** — Replace hardcoded `initial` blocks with external hex file loading for flexible program testing.
- **Additional B-type instructions** — Extend the controller and datapath to support `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`.
- **U-type instructions** — Add `LUI` and `AUIPC` support with an additional immediate format in the generator.
- **FPGA synthesis** — Target a Xilinx or Intel FPGA evaluation board using the existing synthesizable RTL.
