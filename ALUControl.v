// =============================================================================
// ALUControl.v — ALU Operation Decoder
//
// Translates ALUop (from MainController) + funct7[30] + funct3 into
// a 4-bit ALU control word.
//
// ALUop encoding:
//   00  →  ADD (load/store address calculation)
//   01  →  SUB (branch comparison)
//   10  →  R-type (decode from funct7/funct3)
//   11  →  I-type immediate ALU (decode from funct3 only)
//
// ALU control word → operation:
//   0000  AND     0001  OR      0010  ADD     0011  SLL
//   0100  SLT     0101  SLTU    0110  SUB     0111  XOR
//   1000  SRL     1010  SRA
// =============================================================================

module ALUControl (
    input  wire [1:0] ALUop,
    input  wire       funct7,   // bit [30] of instruction (distinguishes ADD/SUB, SRL/SRA)
    input  wire [2:0] funct3,
    output reg  [3:0] Control
);

    always @(*) begin
        case (ALUop)
            2'b00: Control = 4'b0010;   // ADD (load/store)
            2'b01: Control = 4'b0110;   // SUB (branch)

            2'b10: begin                // R-type: use {funct7, funct3}
                case ({funct7, funct3})
                    4'b0_000: Control = 4'b0010; // ADD
                    4'b1_000: Control = 4'b0110; // SUB
                    4'b0_111: Control = 4'b0000; // AND
                    4'b0_110: Control = 4'b0001; // OR
                    4'b0_001: Control = 4'b0011; // SLL
                    4'b0_010: Control = 4'b0100; // SLT
                    4'b0_011: Control = 4'b0101; // SLTU
                    4'b0_100: Control = 4'b0111; // XOR
                    4'b0_101: Control = 4'b1000; // SRL
                    4'b1_101: Control = 4'b1010; // SRA
                    default:  Control = 4'bxxxx;
                endcase
            end

            2'b11: begin                // I-type: funct7 only distinguishes SRLI/SRAI
                case ({funct7, funct3})
                    4'b0_000: Control = 4'b0010; // ADDI
                    4'b0_010: Control = 4'b0100; // SLTI
                    4'b0_011: Control = 4'b0101; // SLTIU
                    4'b0_100: Control = 4'b0111; // XORI
                    4'b0_110: Control = 4'b0001; // ORI
                    4'b0_111: Control = 4'b0000; // ANDI
                    4'b0_001: Control = 4'b0011; // SLLI
                    4'b0_101: Control = 4'b1000; // SRLI
                    4'b1_101: Control = 4'b1010; // SRAI
                    default:  Control = 4'bxxxx;
                endcase
            end

            default: Control = 4'bxxxx;
        endcase
    end

endmodule
