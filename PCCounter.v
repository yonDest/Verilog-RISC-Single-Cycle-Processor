// =============================================================================
// PCCounter.v — Program Counter Register
//
// Synchronous register updated on every rising clock edge.
// PCen is tied high (1'b1) in the top-level for always-running execution.
// Retaining PCen as a port preserves future stall/hazard support.
// =============================================================================

module PCCounter #(
    parameter Width = 32
)(
    input  wire             clk,
    input  wire             PCen,       // 1 = update PC, 0 = stall (hold)
    input  wire [Width-1:0] PC1,        // next PC value
    output reg  [Width-1:0] PC          // current PC
);

    initial PC = {Width{1'b0}};         // reset PC to 0 at simulation start

    always @(posedge clk) begin
        if (PCen)
            PC <= PC1;
        // else: hold current PC (stall)
    end

endmodule
