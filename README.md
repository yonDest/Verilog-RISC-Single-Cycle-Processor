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
- [Potential Extensions](#potential-extensions)

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
                          │                    architecture.v                      │
                          │                                                         │
  ┌────────────┐   PC    ┌┴──────────────────┐  RD[31:0]  ┌─────────────────┐    │
  │ PCCounter  │────────►│ InstructionMemory  │───────────►│ MainController  │    │
  └────────────┘         └───────────────────┘            └────────┬────────┘    │
        ▲                         │                                 │ Control      │
        │                         │ RD[31:0]                        │ signals      │
  ┌─────┴──────┐                  │                                 │              │
  │  MUX(Jump) │◄─── ALUOut ──────│─────────────────────────────────│──────┐      │
  └─────┬──────┘                  │                                 │      │      │
        │                         ▼                                 │      │      │
  ┌─────┴──────┐         ┌─────────────────┐                        │      │      │
  │ MUX(Branch)│         │  RegisterFile   │◄── RegWrite ───────────┘      │      │
  └─────┬──────┘         └────────┬────────┘                               │      │
        │                   RD1   │  RD2                                    │      │
        │                         │                                         │      │
  ┌─────┴──────┐  ┌───────────────▼──────┐  ┌──────────────────┐           │      │
  │   Adder    │  │    MUX (Asel)        │  │ ImmediateGenerat.│           │      │
  │   (PC+4)   │  │  rs1 or PC → ALU[A] │  └────────┬─────────┘           │      │
  └─────┬──────┘  └───────────┬──────────┘           │                     │      │
        │                     │ sign-ext to 64b       │  ┌──────────────┐   │      │
        │                     │              ┌────────▼──┤ MUX (ALUSrc) │   │      │
        │                     │              │           │  rs2 or imm  │   │      │
        │                     │              │           └──────┬───────┘   │      │
        │                     │              │                  │            │      │
        │                     └────────► ┌───▼──────────────────▼─────────────┐   │
        │                                │               ALU                   │   │
        │                                │  AND OR ADD SUB SLL SRL SRA        │   │
        │                                │  SLT SLTU XOR  (64-bit)            │   │
        │                                └──────────────┬─────────────────────┘   │
        │                                         ALUOut │  Zero                   │
        │                                               │                          │
        │                                    ┌──────────▼──────┐                  │
        │                                    │   DataMemory    │                  │
        │                                    └──────────┬──────┘                  │
        │                                               │                          │
        │                                    ┌──────────▼──────┐                  │
        └────────────────────────────────────► MUX1 (MemtoReg) │                  │
                                             │ ALUOut|Mem|PC+4 │                  │
                                             └──────────┬──────┘                  │
                                                        │                          │
                                                   WriteData → RegisterFile        │
                                          └───────────────────────────────────────┘
```

---

## Module Breakdown

### `architecture.v` — Top-Level Datapath
Instantiates and wires all submodules using named port connections. Routes control signals from `MainController` to every datapath component. Handles the branch/jump PC selection logic with a two-stage MUX chain — one for branch (gated by `BEQ AND Zero`), one for jump (`JAL`/`JALR`).

### `MainController.v` — Main Control Unit
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
Translates the 2-bit `ALUop` + `funct7[30]` + `funct3[2:0]` into a 4-bit ALU control word covering all 10 ALU operations.

### `ALU.v` — Arithmetic Logic Unit
Parameterized 64-bit ALU supporting `AND`, `OR`, `ADD`, `SUB`, `SLL`, `SLT` (signed), `SLTU` (unsigned), `XOR`, `SRL`, `SRA`. Uses `$signed()` casts for correct signed comparison and arithmetic shift. Outputs a `zero` flag used by the branch logic.

### `RegisterFile.v` — Register File
32 × 32-bit register file. `x0` is hardwired to zero — writes to address 0 are blocked, reads always return 0. Synchronous write on positive clock edge; asynchronous read.

### `InstructionMemory.v` — Instruction ROM
Word-addressed (by byte address), 512-entry ROM pre-loaded with a 17-instruction test program covering all implemented instruction types. Easily extended with `$readmemh` for external program loading.

### `DataMemory.v` — Data RAM
512 × 32-bit word-addressed RAM. Combinational read (`MemRead`) and combinational write (`MemWrite`). Pre-loaded with values `0x00–0x07` for simulation.

### `ImmediateGeneration.v` — Immediate Generator
Extracts and sign-extends immediates for all supported format types. Faithfully reassembles the non-contiguous B-type and J-type bit fields that RISC-V scrambles to reduce mux hardware in pipelined implementations.

| Format | Bits Used |
|---|---|
| I-type | `[31:20]` |
| S-type | `[31:25]`, `[11:7]` |
| B-type | `[31]`, `[7]`, `[30:25]`, `[11:8]` |
| J-type | `[31]`, `[19:12]`, `[20]`, `[30:21]` |

### `PCCounter.v` — Program Counter
Synchronous register updated on each positive clock edge. `PCen` is tied high in the top-level for normal execution; retaining it as a port preserves a clean interface point for future stall/hazard support.

### `MUX.v` — 2-to-1 Multiplexer
Parameterized 2-to-1 MUX. Used for `ALUSrc`, branch/jump PC selection, and ALU A-input selection (`Asel`).

### `MUX1.v` — 3-to-1 Multiplexer (Writeback)
Parameterized 3-to-1 MUX for the writeback stage — selects among ALU result, memory read data, or PC+4 (for JAL/JALR link register write) in a single level of logic.

### `Adder.v` — PC+4 Adder
Dedicated combinational adder that computes `PC + 4` for the sequential program counter update.

### `BranchAdder.v` — Branch Target Adder
Combinational adder for the branch target address: `PC + (imm << 1)`. Receives the already-shifted offset from `LeftShift.v`.

### `LeftShift.v` — Immediate Left-Shift
Left-shifts the sign-extended immediate by 1 bit to recover the true byte offset before it is added to the PC. Required because RISC-V branch and JAL immediates encode offset/2 — the LSB is always 0 and is not stored in the instruction.

---

## Datapath Signal Flow

```
Fetch    →  PC → InstructionMemory → Instruction[31:0]
Decode   →  Instruction → MainController     (control signals)
         →  Instruction → RegisterFile       (rs1, rs2 read)
         →  Instruction → ImmediateGeneration (sign-extended imm)
         →  Instruction → ALUControl          (funct3, funct7)
Execute  →  MUX(Asel):   rs1 or PC  → sign-extend → ALU input A
         →  MUX(ALUSrc): rs2 or imm               → ALU input B
         →  ALU → ALUOut, Zero
         →  BranchGate:  Zero AND Branch → select PCBranch
         →  MUX(Branch): PCPlus4 or PCBranch → PCNext
         →  MUX(Jump):   PCNext   or ALUOut  → PC
Memory   →  DataMemory(ALUOut, rs2) → ReadData
Writeback → MUX1(MemtoReg): ALUOut | ReadData | PC+4 → WriteData → RegisterFile
```

---

## File Structure

```
.
├── architecture.v          # Top-level datapath integration
├── MainController.v        # Opcode → control signal decoder
├── ALUControl.v            # funct3/funct7 → ALU operation decoder
├── ALU.v                   # 64-bit parameterized ALU (10 operations)
├── RegisterFile.v          # 32×32-bit general-purpose register file
├── InstructionMemory.v     # Word-addressed instruction ROM (512 entries)
├── DataMemory.v            # Word-addressed data RAM (512 entries)
├── ImmediateGeneration.v   # Multi-format immediate sign-extension
├── PCCounter.v             # Program counter register
├── MUX.v                   # Parameterized 2-to-1 MUX
├── MUX1.v                  # Parameterized 3-to-1 MUX (writeback select)
├── Adder.v                 # PC+4 combinational adder
├── BranchAdder.v           # Branch target adder (PC + shifted imm)
├── LeftShift.v             # 1-bit left shift for branch/jump offset scaling
└── sim/
    └── tb_architecture.v   # Self-checking testbench with waveform dump
```

---

## Simulation & Getting Started

### Prerequisites
- [Icarus Verilog](http://iverilog.icarus.com/) (open-source), **or**
- Xilinx Vivado / Intel Quartus / ModelSim

### Compile & Simulate (Icarus Verilog)

```bash
iverilog -o sim.vvp sim/tb_architecture.v \
  architecture.v MainController.v ALUControl.v ALU.v \
  RegisterFile.v InstructionMemory.v DataMemory.v \
  ImmediateGeneration.v PCCounter.v MUX.v MUX1.v \
  Adder.v BranchAdder.v LeftShift.v

vvp sim.vvp
```

### View Waveforms

```bash
gtkwave wave.vcd
```

### Expected Output

The testbench runs a self-checking pass/fail suite against all 15 instructions in the pre-loaded program. A clean run prints:

```
==========================================================
  SIMULATION COMPLETE
  PASSED: 18   FAILED: 0   TOTAL: 18
  ✓ All checks passed.
==========================================================
```

### Pre-Loaded Test Program

| Address | Encoding | Instruction | Expected Result |
|---|---|---|---|
| `0x00` | `002081B3` | `add  x3,  x1, x2` | x3 = 3 |
| `0x04` | `403202B3` | `sub  x5,  x4, x3` | x5 = 1 |
| `0x08` | `00308383` | `lw   x7,  3(x1)` | x7 = mem[4] = 4 |
| `0x0C` | `0013F333` | `and  x6,  x7, x1` | x6 = 0 |
| `0x10` | `001112B3` | `sll  x5,  x2, x1` | x5 = 4 |
| `0x14` | `001122B3` | `slt  x5,  x2, x1` | x5 = 0 |
| `0x18` | `00210463` | `beq  x2,  x2, +8` | branch taken → PC = 0x20 |
| `0x1C` | `001132B3` | `sltu x5,  x2, x1` | *(skipped by branch)* |
| `0x20` | `001142B3` | `xor  x5,  x2, x1` | x5 = 3 |
| `0x24` | `001152B3` | `srl  x5,  x2, x1` | x5 = 1 |
| `0x28` | `401152B3` | `sra  x5,  x2, x1` | x5 = 1 |
| `0x2C` | `008002EF` | `jal  x5,  +8` | x5 = 0x30; PC = 0x34 |
| `0x30` | `00110293` | `addi x5,  x2, 1` | *(skipped by jal)* |
| `0x34` | `00312293` | `slti x5,  x2, 3` | x5 = 1 |
| `0x38` | `00517293` | `andi x5,  x2, 5` | x5 = 0 |
| `0x3C` | `00211293` | `slli x5,  x2, 2` | x5 = 8 |
| `0x40` | `002102E7` | `jalr x5,  x2, 2` | PC = 4 (loop back) |

---

## Design Decisions & Notes

**Single-cycle trade-offs.** Every instruction completes in one clock cycle, simplifying control logic at the cost of cycle time being constrained by the longest combinational path — typically a load word instruction traversing fetch → decode → ALU → data memory → writeback.

**64-bit ALU with 32-bit architecture.** The ALU operates on 64-bit operands internally. 32-bit register values are sign-extended before entering the ALU, ensuring correct arithmetic on signed quantities. `$signed()` casts are used for `SLT` and `SRA` rather than manual two's complement manipulation.

**3-to-1 writeback MUX.** A single `MUX1` selects among ALU result, memory data, and `PC+4` in one level of logic, cleanly supporting the JAL/JALR link-register write without extra steering logic.

**Parameterized modules.** `ALU`, `MUX`, `MUX1`, `RegisterFile`, `InstructionMemory`, `DataMemory`, `PCCounter`, `Adder`, `BranchAdder`, and `LeftShift` are all width-parameterized for adaptability without structural changes.

**`PCen` retained as a port.** `PCCounter` exposes a stall pin even though the top-level ties it high. This preserves a clean interface point for adding hazard detection in a future pipelined version without modifying the module itself.

**Named port connections.** `architecture.v` uses named port connections (`.port(signal)`) throughout rather than positional arguments, making wiring auditable and refactoring safe.

---

## Potential Extensions

- **Pipelined version** — Add IF/ID, ID/EX, EX/MEM, MEM/WB pipeline registers with hazard detection and forwarding; `PCen` on `PCCounter` is already in place for stall support.
- **`$readmemh` program loading** — Replace the hardcoded `initial` block in `InstructionMemory.v` with `$readmemh("program.hex", mem)` for flexible program testing.
- **Additional B-type instructions** — Extend `MainController` and the branch logic to support `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`.
- **U-type instructions** — Add `LUI` and `AUIPC` with a new immediate format in `ImmediateGeneration.v`.
- **FPGA synthesis** — The RTL is written to be synthesizable; target a Xilinx or Intel evaluation board with minimal changes.
