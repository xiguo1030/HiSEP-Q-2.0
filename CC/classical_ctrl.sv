`timescale 1ns / 1ps

module classical_ctrl(
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] i_q_measurement, // CHANGED: 32-bit
    // Quantum Interface
    output logic        q_time_write,
    output logic        q_time_sel,
    output logic [1:0]  q_reg_write,
    // output logic        q_vliw,     <-- Removed
    output logic        q_slm,
    output logic        q_rot,
    output logic [31:0] q_inst,        // CHANGED: 32-bit
    output logic [31:0] q_time_reg,    // CHANGED: 32-bit
    output logic [4:0]  meas_rd_addr,
    
    // Memory Interface
    output logic        pram_en,
    output logic        pram_rd_en,
    output logic [10:0] pram_addr,
    input  logic [31:0] instruction,   // 32-bit

    output logic        dram_en,
    output logic        dram_rd_en,
    output logic        dram_wr_en,
    output logic [10:0] dram_addr,
    output logic [31:0] dram_din,      // CHANGED: 32-bit
    input  logic [31:0] data_read,     // CHANGED: 32-bit

    // Misc
    output logic        inverted_clk,
    input  logic [31:0] start_sig,     // CHANGED: 32-bit
    output logic [31:0] end_sig        // CHANGED: 32-bit
);
    // --- Internal Signals (ALL 32-bit) ---
    logic [31:0] next_pc;
    logic [6:0]  opcode;
    logic [4:0]  rd_addr, rs_addr, rt_addr; 
    logic [4:0]  rs1_idx, rs2_idx, rd_idx; 
    logic [4:0]  comp_flag_idx;

    // Control Signals
    logic [3:0] ALU_op;
    logic       reg_write, mem_write, branch;
    logic [2:0] reg_sel, imm_sel;
    logic       sel_mux_b, time_reg_en;

    // Datapath Signals
    logic [11:0] comp_to_ctrl;
    logic [9:0]  comp_from_alu;
    logic [31:0] wr_data, rs_data, rt_data; // CHANGED
    logic [31:0] imm, alu_a, alu_b, alu_out; // CHANGED
    logic        end_reg; 

    // --- Decoding ---
    assign opcode = instruction[6:0];
    assign rd_idx  = instruction[11:7];
    assign rs1_idx = instruction[19:15];
    assign rs2_idx = instruction[24:20];

    logic is_ldui;
    assign is_ldui = (opcode == 7'b0010111);
    
    assign comp_flag_idx = instruction[11:7];

    assign rs_addr = is_ldui ? instruction[16:12] : rs1_idx;
    assign rt_addr = rs2_idx;
    assign rd_addr = rd_idx;

    // --- PC Generation ---
    pc_gen pc_gen_i (
        .clk(clk), .reset(rst),
        .start_sig(start_sig[0]), .end_sig(end_reg),
        .i_sel_pc(branch), .i_pc_from_alu(alu_out),
        .o_pc(next_pc)
    );

    // --- Register File ---
    reg_file reg_file_i (
        .clk(clk), .reset(rst),
        .rs_addr(rs_addr), .rt_addr(rt_addr), .wr_addr(rd_addr),
        .wr_data(wr_data), .wr_en(reg_write),
        .rs_data(rs_data), .rt_data(rt_data)
    );

    // --- Control Unit ---
    control control_i (
        .reset(rst), .opcode(opcode), .funct3(instruction[14:12]),
        .q_inst_sign(1'b0),
        .comp_flag(comp_to_ctrl), .comp_addr(comp_flag_idx),
        .ALU_op(ALU_op), .reg_write(reg_write), .mem_write(mem_write),
        .branch(branch),
        .q_time_write(q_time_write), .q_time_sel(q_time_sel),
        .q_slm(q_slm), .q_rot(q_rot), .q_reg_write(q_reg_write),
        .reg_sel(reg_sel), .imm_sel(imm_sel),
        .o_time_reg_en(time_reg_en), .sel_mux_b(sel_mux_b)
    );
    
    // --- ALU Muxes & ALU ---
    mux_alu_a mux_alu_a_i (
        .i_reg(rs_data),
        .i_pc(next_pc),
        .i_branch_sel(branch), .o_alu_a(alu_a)
    );

    mux_alu_b mux_alu_b_i (
        .i_reg(rt_data),
        .i_imm(imm),
        .i_imm_sel(sel_mux_b), .o_alu_b(alu_b)
    );

    alu alu_i (
        .op_A(alu_a), .op_B(alu_b), .ALU_op(ALU_op),
        .result(alu_out), .comp_flag(comp_from_alu)
    );

    // --- Immediate Gen & Writeback Mux ---
    imm_gen imm_gen_i (
        .instr(instruction), .imm_sel(imm_sel),
        .i_regs(rs_data), .imm_out(imm)
    );

    mux_2_reg mux_2_reg_i (
        .i_from_data_mem(data_read), .i_from_alu(alu_out),
        .i_from_q_measure(i_q_measurement),
        .i_from_comp_flg({20'b0, comp_to_ctrl}), // CHANGED: Padding 20 bits instead of 52
        .i_from_imm(imm),
        .sel_from_ctrl(reg_sel),
        .o_2_regfile(wr_data)
    );

    // --- State & Misc Logic ---
    comp_reg comp_reg_i (
        .clk(clk), .reset(rst),
        .i_comp_flag(comp_from_alu), .ALU_op(ALU_op),
        .o_comp_reg(comp_to_ctrl)
    );

    clk_inverter clk_inverter_i (.clk(clk), .reset(rst), .inverted_clk(inverted_clk));

    // End Signal Logic
    always_ff @(posedge clk) begin
        if (rst) end_reg <= 1'b0;
        else if (opcode == 7'b0001000) end_reg <= 1'b1; 
    end
    assign end_sig = {31'b0, end_reg}; // CHANGED

    // Outputs
    assign q_inst       = instruction; // CHANGED: Direct 32-bit assignment
    assign q_time_reg   = time_reg_en ? rs_data : 32'b0; // CHANGED
    assign meas_rd_addr = {2'b0, instruction[13:11]};

    assign pram_en      = start_sig[0] & ~end_reg;
    assign pram_rd_en   = start_sig[0] & ~end_reg;
    assign pram_addr    = next_pc[10:0];

    assign dram_en      = start_sig[0] & ~end_reg;
    assign dram_rd_en   = start_sig[0] & ~end_reg;
    assign dram_wr_en   = mem_write;
    assign dram_addr    = alu_out[10:0];
    assign dram_din     = rt_data;

endmodule