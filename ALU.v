// =============================================================================
// ALU.v — Arithmetic Logic Unit
//
// Parameterized width (default 64-bit). Supports 10 operations selected
// by a 4-bit control word from ALUControl.
//
// Control → Operation:
//   0000  AND          0001  OR           0010  ADD
//   0011  SLL          0100  SLT (signed) 0101  SLTU (unsigned)
//   0110  SUB          0111  XOR          1000  SRL
//   1010  SRA
//
// Outputs a Zero flag used by the branch logic (BEQ).
// =============================================================================

module ALU #(
    parameter Width = 64
)(
    input  wire [3:0]       controlsignal,
    input  wire [Width-1:0] A1,
    input  wire [Width-1:0] A2,
    output reg  [Width-1:0] Y,
    output wire             zero
);

    always @(*) begin
        case (controlsignal)
            4'b0000: Y = A1 & A2;                          // AND
            4'b0001: Y = A1 | A2;                          // OR
            4'b0010: Y = A1 + A2;                          // ADD
            4'b0011: Y = A1 << A2;                         // SLL
            4'b0100: Y = ($signed(A1) < $signed(A2)) ? 1 : 0; // SLT  (signed)
            4'b0101: Y = (A1 < A2)                  ? 1 : 0; // SLTU (unsigned)
            4'b0110: Y = A1 - A2;                          // SUB
            4'b0111: Y = A1 ^ A2;                          // XOR
            4'b1000: Y = A1 >> A2;                         // SRL
            4'b1010: Y = $signed(A1) >>> A2;               // SRA
            default: Y = {Width{1'bx}};
        endcase
    end

    assign zero = (Y == 0);

endmodule
