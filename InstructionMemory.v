// =============================================================================
// InstructionMemory.v — Instruction ROM
//
// Word-addressed (4-byte aligned), 512-entry read-only memory.
// Pre-loaded with a test program covering all supported instruction types.
//
// To load an external program instead, replace the initial block with:
//   $readmemh("program.hex", mem);
// =============================================================================

module InstructionMemory #(
    parameter Width = 32
)(
    input  wire [Width-1:0] address,
    output wire [Width-1:0] RD
);

    reg [Width-1:0] mem [511:0];

    initial begin
        // -------------------------------------------------------------------
        // Test program — exercises all supported instruction types.
        // Byte addresses used; memory is word-addressed (mem[addr]).
        // -------------------------------------------------------------------
        mem[0]  = 32'h002081B3; // add  x3,  x1, x2        R:  x3  = 1+2  = 3
        mem[4]  = 32'h403202B3; // sub  x5,  x4, x3        R:  x5  = 4-3  = 1
        mem[8]  = 32'h00308383; // lw   x7,  3(x1)         I:  x7  = mem[4] = 4
        mem[12] = 32'h0013F333; // and  x6,  x7, x1        R:  x6  = 4&1  = 0
        mem[16] = 32'h001112B3; // sll  x5,  x2, x1        R:  x5  = 2<<1 = 4
        mem[20] = 32'h001122B3; // slt  x5,  x2, x1        R:  x5  = (2<1)= 0
        mem[24] = 32'h00210463; // beq  x2,  x2, +8        B:  branch → PC=0x20
        mem[28] = 32'h001132B3; // sltu x5,  x2, x1        R:  (skipped by branch)
        mem[32] = 32'h001142B3; // xor  x5,  x2, x1        R:  x5  = 2^1  = 3
        mem[36] = 32'h001152B3; // srl  x5,  x2, x1        R:  x5  = 2>>1 = 1
        mem[40] = 32'h401152B3; // sra  x5,  x2, x1        R:  x5  = 2>>>1= 1
        mem[44] = 32'h008002EF; // jal  x5,  +8            J:  x5=PC+4; PC=0x34
        mem[48] = 32'h00110293; // addi x5,  x2, 1         I:  (skipped by jal)
        mem[52] = 32'h00312293; // slti x5,  x2, 3         I:  x5  = (2<3)= 1
        mem[56] = 32'h00517293; // andi x5,  x2, 5         I:  x5  = 2&5  = 0
        mem[60] = 32'h00211293; // slli x5,  x2, 2         I:  x5  = 2<<2 = 8
        mem[64] = 32'h002102E7; // jalr x5,  x2, 2         I:  PC=x2+2=4 (loop)
    end

    assign RD = mem[address];

endmodule
