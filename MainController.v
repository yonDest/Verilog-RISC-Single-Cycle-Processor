// =============================================================================
// MainController.v — Main Control Unit
//
// Decodes the 7-bit opcode into 9 datapath control signals.
//
// Opcode map:
//   0110011  R-type   (add, sub, and, or, xor, sll, srl, sra, slt, sltu)
//   0000011  I-type   load  (lw)
//   0100011  S-type   store (sw)
//   1100011  B-type   branch (beq)
//   0010011  I-type   immediate ALU (addi, andi, ori, ...)
//   1100111  I-type   JALR
//   1101111  J-type   JAL
// =============================================================================

module MainController (
    input  wire [6:0] Opcode,
    output wire       ALUSrc,    // 0=rs2, 1=immediate
    output wire [1:0] MemtoReg,  // 00=ALU, 01=memory, 10=PC+4
    output wire       RegWrite,  // enable register write
    output wire       MemRead,   // enable data memory read
    output wire       MemWrite,  // enable data memory write
    output wire       Branch,    // enable branch condition
    output wire       Jump,      // override PC with jump target
    output wire       Asel,      // 0=rs1 to ALU, 1=PC to ALU
    output wire [1:0] ALUop      // ALU operation class
);

    reg [8:0] control;

    // Pack all signals into one bus for concise assignment
    assign {ALUSrc, MemtoReg, RegWrite, MemRead, MemWrite, Branch, Jump, ALUop} = control;

    always @(*) begin
        case (Opcode)
            //                    AS MT RW MR MW BR JP ALUOP
            7'b0110011: control = 9'b0_01_1_0_0_0_0_10; // R-type
            7'b0000011: control = 9'b1_01_1_1_0_0_0_00; // lw
            7'b0100011: control = 9'b1_xx_0_0_1_0_0_00; // sw
            7'b1100011: control = 9'b0_xx_0_0_0_1_0_01; // beq
            7'b0010011: control = 9'b1_01_1_0_0_0_0_11; // I-type ALU
            7'b1100111: control = 9'b1_10_1_x_0_0_1_00; // jalr
            7'b1101111: control = 9'b1_10_1_x_0_0_1_00; // jal
            default:    control = 9'bx_xx_x_x_x_x_x_xx;
        endcase
    end

endmodule
