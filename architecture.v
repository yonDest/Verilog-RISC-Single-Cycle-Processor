// =============================================================================
// architecture.v — Top-Level Single-Cycle RISC-V Datapath
//
// Instantiates and wires all datapath and control submodules.
// Supports: R-type, I-type (load + immediate ALU), S-type, B-type (BEQ),
//           J-type (JAL, JALR)
// =============================================================================

module architecture (
    input clk
);

    // -------------------------------------------------------------------------
    // Internal wires
    // -------------------------------------------------------------------------

    // 64-bit datapath signals
    wire [63:0] ALUOut, ALUInputA, ALUInputB;
    wire [63:0] ImmExt, RD1, RD2, WriteData, DataOut;
    wire [63:0] PCPlus4Ext, ShiftedImm;

    // 32-bit PC and instruction signals
    wire [31:0] PC, PCNext, PCPlus4, PCBranch, PCJump;
    wire [31:0] Instruction;

    // Control signals
    wire        ALUSrc, RegWrite, MemRead, MemWrite, Branch, Jump, Asel;
    wire [1:0]  ALUop, MemtoReg;
    wire [3:0]  ALUControl;

    // Misc
    wire        Zero, BranchTaken;

    // -------------------------------------------------------------------------
    // PC update logic
    //   PCBranch = PC + (imm << 1)
    //   PCJump   = ALUOut[31:0]       (JALR: rs1 + imm)
    //   PCNext   = branch ? PCBranch : PCPlus4
    //   PC       = jump   ? PCJump   : PCNext
    // -------------------------------------------------------------------------

    and BranchGate (BranchTaken, Branch, Zero);

    Adder         PC4    (.PC(PC),       .PCPlus4(PCPlus4));
    BranchAdder   BrAdd  (.A(PC),        .B(ShiftedImm[31:0]), .Y(PCBranch));
    LeftShift     Sh     (.In(ImmExt),   .Out(ShiftedImm));

    MUX #(32)     BrMux  (.a(PCPlus4),  .b(PCBranch),       .s(BranchTaken), .out(PCNext));
    MUX #(32)     JpMux  (.a(PCNext),   .b(ALUOut[31:0]),   .s(Jump),        .out(PCJump));

    PCCounter     PCC    (.clk(clk),    .PCen(1'b1),        .PC1(PCJump),    .PC(PC));

    // -------------------------------------------------------------------------
    // Fetch
    // -------------------------------------------------------------------------

    InstructionMemory  IMem (.address(PC), .RD(Instruction));

    // -------------------------------------------------------------------------
    // Decode
    // -------------------------------------------------------------------------

    MainController  Ctrl (
        .Opcode   (Instruction[6:0]),
        .ALUSrc   (ALUSrc),
        .MemtoReg (MemtoReg),
        .RegWrite (RegWrite),
        .MemRead  (MemRead),
        .MemWrite (MemWrite),
        .Branch   (Branch),
        .Jump     (Jump),
        .Asel     (Asel),
        .ALUop    (ALUop)
    );

    RegisterFile  RF (
        .clk      (clk),
        .RegWrite (RegWrite),
        .R1       (Instruction[19:15]),   // rs1
        .R2       (Instruction[24:20]),   // rs2
        .W1       (Instruction[11:7]),    // rd
        .WD1      (WriteData),
        .RD1      (RD1),
        .RD2      (RD2)
    );

    ImmediateGeneration  ImmGen (
        .In  (Instruction),
        .Out (ImmExt)
    );

    // -------------------------------------------------------------------------
    // Execute
    // -------------------------------------------------------------------------

    // ALU input A: rs1 or PC (for JAL/JALR)
    MUX #(64)     AMux (.a(RD1), .b({{32{PC[31]}}, PC}), .s(Asel), .out(ALUInputA));

    // ALU input B: rs2 or sign-extended immediate
    MUX #(64)     BMux (.a(RD2), .b(ImmExt),              .s(ALUSrc), .out(ALUInputB));

    ALUControl  ALUC (
        .ALUop  (ALUop),
        .funct7 (Instruction[30]),
        .funct3 (Instruction[14:12]),
        .Control(ALUControl)
    );

    ALU  MainALU (
        .controlsignal (ALUControl),
        .A1            (ALUInputA),
        .A2            (ALUInputB),
        .Y             (ALUOut),
        .zero          (Zero)
    );

    // -------------------------------------------------------------------------
    // Memory
    // -------------------------------------------------------------------------

    DataMemory  DMem (
        .clk       (clk),
        .MemWrite  (MemWrite),
        .MemRead   (MemRead),
        .address   (ALUOut[31:0]),
        .WriteData (RD2),
        .ReadData  (DataOut)
    );

    // -------------------------------------------------------------------------
    // Writeback — 3-way MUX: ALU result | memory load | PC+4 (link register)
    // -------------------------------------------------------------------------

    assign PCPlus4Ext = {{32{PCPlus4[31]}}, PCPlus4};

    MUX1 #(64)  WBMux (
        .a   (ALUOut),
        .b   (DataOut),
        .c   (PCPlus4Ext),
        .s   (MemtoReg),
        .out (WriteData)
    );

endmodule
