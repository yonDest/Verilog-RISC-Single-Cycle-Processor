// =============================================================================
// RegisterFile.v — General-Purpose Register File
//
// 32 registers × 32-bit wide.
//   - x0 is hardwired to zero (reads always return 0).
//   - Synchronous write on rising clock edge when RegWrite is asserted.
//   - Asynchronous (combinational) read.
//
// Registers x1–x10 are pre-initialized for simulation.
// =============================================================================

module RegisterFile #(
    parameter Width = 32
)(
    input  wire             clk,
    input  wire             RegWrite,
    input  wire [4:0]       R1,        // rs1 address
    input  wire [4:0]       R2,        // rs2 address
    input  wire [4:0]       W1,        // rd  address
    input  wire [Width-1:0] WD1,       // write data
    output wire [Width-1:0] RD1,       // rs1 read data
    output wire [Width-1:0] RD2        // rs2 read data
);

    reg [Width-1:0] Registers [Width-1:0];

    // Pre-load registers for simulation (x1=1, x2=2, ... x10=16)
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            Registers[i] = 0;
        Registers[1]  = 32'h00000001;
        Registers[2]  = 32'h00000002;
        Registers[3]  = 32'h00000003;
        Registers[4]  = 32'h00000004;
        Registers[5]  = 32'h00000005;
        Registers[6]  = 32'h00000006;
        Registers[7]  = 32'h00000007;
        Registers[8]  = 32'h00000008;
        Registers[9]  = 32'h00000009;
        Registers[10] = 32'h00000010;
    end

    // Synchronous write
    always @(posedge clk) begin
        if (RegWrite && W1 != 5'd0)   // x0 is read-only
            Registers[W1] <= WD1;
    end

    // Asynchronous read — x0 always returns 0
    assign RD1 = (R1 != 5'd0) ? Registers[R1] : {Width{1'b0}};
    assign RD2 = (R2 != 5'd0) ? Registers[R2] : {Width{1'b0}};

endmodule
