// =============================================================================
// BranchAdder.v — Branch Target Address Adder
//
// Computes the branch target: PC + (imm << 1).
// The left-shift is handled upstream by LeftShift.v; this module receives
// the already-shifted offset and adds it to the current PC.
// =============================================================================

module BranchAdder #(
    parameter Width = 32
)(
    input  wire [Width-1:0] A,      // current PC
    input  wire [Width-1:0] B,      // shifted immediate (imm << 1)
    output wire [Width-1:0] Y       // branch target address
);

    assign Y = A + B;

endmodule
