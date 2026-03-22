// =============================================================================
// MUX.v — Parameterized 2-to-1 Multiplexer
//
// Used for: ALUSrc, Branch/Jump PC selection, ALU A-input selection (Asel).
// =============================================================================

module MUX #(
    parameter Width = 32
)(
    input  wire [Width-1:0] a,      // selected when s = 0
    input  wire [Width-1:0] b,      // selected when s = 1
    input  wire             s,      // select
    output wire [Width-1:0] out
);

    assign out = s ? b : a;

endmodule
