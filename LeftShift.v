// =============================================================================
// LeftShift.v — 1-Bit Left Shift for Branch/Jump Offset Scaling
//
// RISC-V branch and JAL immediates encode the offset in units of 2 bytes
// (the LSB is always 0 and is not stored). This module left-shifts the
// sign-extended immediate by 1 to recover the true byte offset before
// it is added to the PC in BranchAdder.
// =============================================================================

module LeftShift #(
    parameter Width = 32
)(
    input  wire [Width-1:0] In,
    output wire [Width-1:0] Out
);

    assign Out = In << 1;

endmodule
