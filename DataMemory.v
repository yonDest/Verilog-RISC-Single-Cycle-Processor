// =============================================================================
// DataMemory.v — Data RAM
//
// Word-addressed, 512-entry synchronous-write / combinational-read memory.
// Pre-initialized with values 0x00–0x07 for simulation.
// =============================================================================

module DataMemory #(
    parameter Width = 32
)(
    input  wire             clk,
    input  wire             MemWrite,
    input  wire             MemRead,
    input  wire [Width-1:0] address,
    input  wire [Width-1:0] WriteData,
    output reg  [Width-1:0] ReadData
);

    reg [Width-1:0] mem [511:0];

    initial begin
        mem[0] = 32'h00000000;
        mem[1] = 32'h00000001;
        mem[2] = 32'h00000002;
        mem[3] = 32'h00000003;
        mem[4] = 32'h00000004;
        mem[5] = 32'h00000005;
        mem[6] = 32'h00000006;
        mem[7] = 32'h00000007;
    end

    always @(*) begin
        if (MemRead)
            ReadData = mem[address];
        else if (MemWrite)
            mem[address] = WriteData;
        else
            ReadData = {Width{1'b0}};
    end

endmodule
