// =============================================================================
// Adder.v — PC+4 Combinational Adder
//
// Dedicated adder for the sequential program counter increment.
// Separate from BranchAdder to keep the two paths structurally distinct.
// =============================================================================

module Adder #(
    parameter Width = 32
)(
    input  wire [Width-1:0] PC,
    output wire [Width-1:0] PCPlus4
);

    assign PCPlus4 = PC + 32'd4;

endmodule
