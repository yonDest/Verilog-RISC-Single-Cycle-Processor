// =============================================================================
// tb_architecture.v — Self-Checking Testbench
// RISC-V Single-Cycle Processor
//
// Drives the clock, monitors every cycle via hierarchical references,
// and self-checks expected register values after key instructions execute.
//
// Simulator:  Icarus Verilog (iverilog) or any IEEE 1364-2001 simulator
// Waveforms:  GTKWave — open wave.vcd after simulation
//
// Compile & run:
//   iverilog -o sim.vvp tb_architecture.v architecture.v ALU.v ALUControl.v \
//            mainController.v Registerfile.v InstructionMemory.v DataMemory.v \
//            ImmediateGeneration.v PCCounter.v MUX.v MUX1.v Adder.v add.v shift.v
//   vvp sim.vvp
//   gtkwave wave.vcd
// =============================================================================

`timescale 1ns/1ps

module tb_architecture;

    // -------------------------------------------------------------------------
    // Clock generation — 10 ns period (100 MHz)
    // -------------------------------------------------------------------------
    reg clk;
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    architecture uut (.clk(clk));

    // -------------------------------------------------------------------------
    // Waveform dump — open wave.vcd in GTKWave
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_architecture);   // dump entire hierarchy
    end

    // -------------------------------------------------------------------------
    // Hierarchical signal aliases — makes $monitor readable
    // -------------------------------------------------------------------------
    wire [31:0] PC          = uut.PC;
    wire [31:0] instr       = uut.RD;
    wire [31:0] alu_out     = uut.ALUOut[31:0];
    wire        zero_flag   = uut.Zero;
    wire        branch      = uut.Branch;
    wire        jump        = uut.jump;
    wire        reg_write   = uut.RegWrite;
    wire        mem_read    = uut.MemRead;
    wire        mem_write   = uut.MemWrite;
    wire [63:0] write_data  = uut.Writedata;

    // Register file — x0..x10 (x0 is hardwired 0 by the register file)
    wire [31:0] x0  = uut.R1.Register[0];
    wire [31:0] x1  = uut.R1.Register[1];
    wire [31:0] x2  = uut.R1.Register[2];
    wire [31:0] x3  = uut.R1.Register[3];
    wire [31:0] x4  = uut.R1.Register[4];
    wire [31:0] x5  = uut.R1.Register[5];
    wire [31:0] x6  = uut.R1.Register[6];
    wire [31:0] x7  = uut.R1.Register[7];

    // -------------------------------------------------------------------------
    // Cycle-by-cycle monitor — prints one line per rising edge
    // -------------------------------------------------------------------------
    integer cycle_count;
    initial cycle_count = 0;

    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        $display("----------------------------------------------------------");
        $display("CYCLE %0d | PC=0x%08h | INSTR=0x%08h", cycle_count, PC, instr);
        $display("         | ALUOut=0x%08h | Zero=%b | Branch=%b | Jump=%b",
                  alu_out, zero_flag, branch, jump);
        $display("         | RegWrite=%b | MemRead=%b | MemWrite=%b",
                  reg_write, mem_read, mem_write);
        $display("  REGFILE: x1=%0d x2=%0d x3=%0d x4=%0d x5=%0d x6=%0d x7=%0d",
                  x1, x2, x3, x4, x5, x6, x7);
    end

    // -------------------------------------------------------------------------
    // Self-checking task
    //   check(signal, expected, label)
    //   Prints PASS or FAIL with context.
    // -------------------------------------------------------------------------
    integer pass_count, fail_count;
    initial begin
        pass_count = 0;
        fail_count = 0;
    end

    task check;
        input [63:0] got;
        input [63:0] expected;
        input [127:0] label;
        begin
            if (got === expected) begin
                $display("  [PASS] %s = %0d (0x%h)", label, got, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %s: expected %0d (0x%h), got %0d (0x%h)",
                          label, expected, expected, got, got);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus & assertions
    //
    // Initial register file values (from Registerfile.v):
    //   x1=1, x2=2, x3=3, x4=4, x5=5, x6=6, x7=7, x8=8, x9=9, x10=16
    //
    // Pre-loaded instruction program (from InstructionMemory.v):
    //   PC=0x00  add  x3, x1, x2      R  x3 = 1+2 = 3
    //   PC=0x04  sub  x5, x4, x3      R  x5 = 4-3 = 1
    //   PC=0x08  lw   x7, 3(x1)       I  x7 = mem[4] = 4
    //   PC=0x0C  and  x6, x7, x1      R  x6 = 4 & 1 = 0
    //   PC=0x10  sll  x5, x2, x1      R  x5 = 2 << 1 = 4
    //   PC=0x14  slt  x5, x2, x1      R  x5 = (2<1) = 0
    //   PC=0x18  beq  x2, x2, +8      B  branch taken → PC = 0x20
    //   PC=0x1C  sltu x5, x2, x1      R  (skipped by branch)
    //   PC=0x20  xor  x5, x2, x1      R  x5 = 2^1 = 3
    //   PC=0x24  srl  x5, x2, x1      R  x5 = 2>>1 = 1
    //   PC=0x28  sra  x5, x2, x1      R  x5 = 2>>>1 = 1
    //   PC=0x2C  jal  x5, +8          J  x5=PC+4; PC=0x34
    //   PC=0x30  addi x5, x2, 1       I  (may be skipped by jal)
    //   PC=0x34  slti x5, x2, 3       I  x5 = (2<3) = 1
    //   PC=0x38  andi x5, x2, 5       I  x5 = 2&5 = 0
    //   PC=0x3C  slli x5, x2, 2       I  x5 = 2<<2 = 8
    //   PC=0x40  jalr x5, x2, 2       I  x5=PC+4; PC=x2+2=4 → loops
    // -------------------------------------------------------------------------

    initial begin
        $display("==========================================================");
        $display("  RISC-V Single-Cycle Processor — Simulation Start");
        $display("==========================================================");

        // ------------------------------------------------------------------
        // Cycle 1:  add x3, x1, x2   →   x3 = 1 + 2 = 3
        // ------------------------------------------------------------------
        @(negedge clk);    // sample after rising edge settles
        #1;
        $display("\n>>> Checking Cycle 1: add x3, x1, x2");
        check(x3, 32'd3, "x3 after ADD");

        // ------------------------------------------------------------------
        // Cycle 2:  sub x5, x4, x3   →   x5 = 4 - 3 = 1
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 2: sub x5, x4, x3");
        check(x5, 32'd1, "x5 after SUB");

        // ------------------------------------------------------------------
        // Cycle 3:  lw x7, 3(x1)     →   x7 = DataMemory[4] = 4
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 3: lw x7, 3(x1)");
        check(x7, 32'd4, "x7 after LW");

        // ------------------------------------------------------------------
        // Cycle 4:  and x6, x7, x1   →   x6 = 4 & 1 = 0
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 4: and x6, x7, x1");
        check(x6, 32'd0, "x6 after AND");

        // ------------------------------------------------------------------
        // Cycle 5:  sll x5, x2, x1   →   x5 = 2 << 1 = 4
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 5: sll x5, x2, x1");
        check(x5, 32'd4, "x5 after SLL");

        // ------------------------------------------------------------------
        // Cycle 6:  slt x5, x2, x1   →   x5 = (2 < 1) signed = 0
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 6: slt x5, x2, x1");
        check(x5, 32'd0, "x5 after SLT");

        // ------------------------------------------------------------------
        // Cycle 7:  beq x2, x2, +8   →   branch taken, PC jumps to 0x20
        //           (no register write; verify PC after next rising edge)
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 7: beq x2, x2 (branch taken)");
        $display("  NOTE: PC should advance to 0x20 (0x18 + 8), skipping 0x1C");
        // PC is sampled on the *next* rising edge; check it after cycle 8 fetch
        check(PC, 32'h00000020, "PC after BEQ taken");

        // ------------------------------------------------------------------
        // Cycle 8:  xor x5, x2, x1   →   x5 = 2 ^ 1 = 3  (0x1C was skipped)
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 8: xor x5, x2, x1 (0x1C was skipped)");
        check(x5, 32'd3, "x5 after XOR");

        // ------------------------------------------------------------------
        // Cycle 9:  srl x5, x2, x1   →   x5 = 2 >> 1 = 1
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 9: srl x5, x2, x1");
        check(x5, 32'd1, "x5 after SRL");

        // ------------------------------------------------------------------
        // Cycle 10: sra x5, x2, x1   →   x5 = 2 >>> 1 = 1 (positive, same)
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 10: sra x5, x2, x1");
        check(x5, 32'd1, "x5 after SRA");

        // ------------------------------------------------------------------
        // Cycle 11: jal x5, +8       →   PC = 0x34, x5 = 0x30 (PC+4)
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 11: jal x5, +8");
        check(x5, 32'h00000030, "x5 (link addr) after JAL");
        check(PC, 32'h00000034, "PC after JAL");

        // ------------------------------------------------------------------
        // Cycle 12: slti x5, x2, 3   →   x5 = (2 < 3) signed = 1
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 12: slti x5, x2, 3");
        check(x5, 32'd1, "x5 after SLTI");

        // ------------------------------------------------------------------
        // Cycle 13: andi x5, x2, 5   →   x5 = 2 & 5 = 0
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 13: andi x5, x2, 5");
        check(x5, 32'd0, "x5 after ANDI");

        // ------------------------------------------------------------------
        // Cycle 14: slli x5, x2, 2   →   x5 = 2 << 2 = 8
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 14: slli x5, x2, 2");
        check(x5, 32'd8, "x5 after SLLI");

        // ------------------------------------------------------------------
        // Cycle 15: jalr x5, x2, 2   →   PC = x2+2 = 4, x5 = 0x44 (PC+4)
        //           Causes a loop back — run a few more cycles then stop.
        // ------------------------------------------------------------------
        @(posedge clk); @(negedge clk); #1;
        $display("\n>>> Checking Cycle 15: jalr x5, x2, 2 (jumps back to PC=4)");
        check(x5, 32'h00000044, "x5 (link addr) after JALR");
        check(PC, 32'h00000004, "PC after JALR");

        // Run a few more cycles to confirm the loop is stable
        repeat (3) @(posedge clk);

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("\n==========================================================");
        $display("  SIMULATION COMPLETE");
        $display("  PASSED: %0d   FAILED: %0d   TOTAL: %0d",
                  pass_count, fail_count, pass_count + fail_count);
        if (fail_count == 0)
            $display("  ✓ All checks passed.");
        else
            $display("  ✗ %0d check(s) failed — inspect wave.vcd in GTKWave.", fail_count);
        $display("==========================================================");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog — prevents infinite loops from hanging CI or terminals
    // -------------------------------------------------------------------------
    initial begin
        #2000;
        $display("[TIMEOUT] Simulation exceeded 2000 ns — forcing stop.");
        $finish;
    end

endmodule
