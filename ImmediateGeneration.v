// =============================================================================
// ImmediateGeneration.v — Immediate Extractor & Sign-Extender
//
// Extracts and sign-extends immediates for each RISC-V instruction format.
// RISC-V deliberately scrambles immediate bit positions to reduce mux hardware
// in pipelined designs; this module faithfully reassembles them.
//
// Format → bits used:
//   I-type  [31:20]                               → 12-bit signed
//   S-type  [31:25] [11:7]                        → 12-bit signed
//   B-type  [31] [7] [30:25] [11:8]               → 13-bit signed (LSB=0)
//   J-type  [31] [19:12] [20] [30:21]             → 21-bit signed (LSB=0)
// =============================================================================

module ImmediateGeneration #(
    parameter Width = 32
)(
    input  wire [Width-1:0] In,
    output reg  [Width-1:0] Out
);

    always @(*) begin
        case (In[6:0])
            // I-type: load, JALR, immediate ALU
            7'b0000011,
            7'b1100111,
            7'b0010011: Out = {{(Width-12){In[31]}}, In[31:20]};

            // S-type: store
            7'b0100011: Out = {{(Width-12){In[31]}}, In[31:25], In[11:7]};

            // B-type: branch (note: encodes offset/2, LSB implied 0)
            7'b1100011: Out = {{(Width-12){In[31]}}, In[31], In[7], In[30:25], In[11:8]};

            // J-type: JAL (encodes offset/2, LSB implied 0)
            7'b1101111: Out = {{(Width-20){In[31]}}, In[31], In[19:12], In[20], In[30:21]};

            default:    Out = {Width{1'b0}};
        endcase
    end

endmodule
