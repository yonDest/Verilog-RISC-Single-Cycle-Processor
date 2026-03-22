// =============================================================================
// MUX1.v — Parameterized 3-to-1 Multiplexer (Writeback Select)
//
// Selects the writeback data source:
//   s = 2'b00  →  a  (ALU result)
//   s = 2'b01  →  b  (data memory read)
//   s = 2'b10  →  c  (PC+4, for JAL/JALR link register write)
// =============================================================================

module MUX1 #(
    parameter Width = 32
)(
    input  wire [Width-1:0] a,      // ALU result
    input  wire [Width-1:0] b,      // memory read data
    input  wire [Width-1:0] c,      // PC+4 (link address)
    input  wire [1:0]       s,      // select
    output wire [Width-1:0] out
);

    assign out = (s == 2'b10) ? c :
                 (s == 2'b01) ? b : a;

endmodule
