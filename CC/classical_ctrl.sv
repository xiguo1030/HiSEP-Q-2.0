`timescale 1ns / 1ps

module classical_ctrl(
    input  logic        clk,
    input  logic        rst,
    input  logic [63:0] i_q_measurement,
    // Quantum Interface
    output logic        q_time_write,
    output logic        q_time_sel,
    output logic [1:0]  q_reg_write,
    output logic        q_vliw,
    output logic        q_slm,
    output logic        q_rot,
    output logic [63:0] q_inst,
    output logic [63:0] q_time_reg,
    output logic [4:0]  meas_rd_addr,
    
    // Memory Interface
    output logic        pram_en,
    output logic        pram_rd_en,
    output logic [10:0] pram_addr,
    input  logic [63:0] instruction,

    output logic        dram_en,
    output logic        dram_rd_en,
    output logic        dram_wr_en,
    output logic [10:0] dram_addr,
    output logic [63:0] dram_din,
    input  logic [63:0] data_read,

    // Misc
    output logic        inverted_clk, // Kept for legacy compatibility
    input  logic [63:0] start_sig,
    output logic [63:0] end_sig
);

    // --- Internal Signals ---
    logic [63:0] next_pc, pc_val;
    logic [6:0]  opcode;
    logic        q_inst_sign;
    logic [3:0]  comp_addr;
    logic [4:0]  rd_addr, rs_addr, rt_addr;

    // Control Signals
    logic [3:0] ALU_op;
    logic       reg_write, mem_write, branch;
    logic [2:0] reg_sel, imm_sel;
    logic       sel_mux_b, time_reg_en;
    logic       s_vliw;

    // Datapath Signals
    logic [11:0] comp_to_ctrl;
    logic [9:0]  comp_from_alu;
    logic [63:0] wr_data, rs_data, rt_data;
    logic [63:0] imm, alu_a, alu_b, alu_out;
    logic        end_reg; 

    // --- Decoding ---
    assign opcode      = instruction[62:56];
    assign q_inst_sign = instruction[63];
    assign rd_addr     = instruction[55:51];
    assign rs_addr     = instruction[50:46];
    assign rt_addr     = instruction[45:41];
    assign comp_addr   = instruction[3:0];

    // --- PC Generation ---
    pc_gen pc_gen_i (
        .clk(clk), .reset(rst),
        .start_sig(start_sig[0]), .end_sig(end_reg),
        .i_sel_pc(branch), .i_pc_from_alu(alu_out),
        .o_pc(pc_val)
    );
    assign next_pc = pc_val; // Helper if you need next_pc logic externally

    // --- Register File ---
    reg_file reg_file_i (
        .clk(clk), .reset(rst),
        .rs_addr(rs_addr), .rt_addr(rt_addr), .wr_addr(rd_addr),
        .wr_data(wr_data), .wr_en(reg_write),
        .rs_data(rs_data), .rt_data(rt_data)
    );

    // --- Control Unit ---
    control control_i (
        .reset(rst), .opcode(opcode), .q_inst_sign(q_inst_sign),
        .comp_flag(comp_to_ctrl), .comp_addr(comp_addr),
        .ALU_op(ALU_op), .reg_write(reg_write), .mem_write(mem_write),
        .branch(branch),
        .q_time_write(q_time_write), .q_time_sel(q_time_sel),
        .q_vliw(s_vliw), .q_slm(q_slm), .q_rot(q_rot), .q_reg_write(q_reg_write),
        .reg_sel(reg_sel), .imm_sel(imm_sel),
        .o_time_reg_en(time_reg_en), .sel_mux_b(sel_mux_b)
    );

    // --- ALU Muxes & ALU ---
    mux_alu_a mux_alu_a_i (
        .i_reg(rt_data), .i_pc(pc_val),
        .i_branch_sel(branch), .o_alu_a(alu_a)
    );

    mux_alu_b mux_alu_b_i (
        .i_reg(rs_data), .i_imm(imm),
        .i_imm_sel(sel_mux_b), .o_alu_b(alu_b)
    );

    alu alu_i (
        .op_A(alu_a), .op_B(alu_b), .ALU_op(ALU_op),
        .result(alu_out), .comp_flag(comp_from_alu)
    );

    // --- Immediate Gen & Writeback Mux ---
    imm_gen imm_gen_i (
        .imm_src(instruction[24:0]), .imm_sel(imm_sel),
        .i_regs(rs_data), .imm_out(imm)
    );

    mux_2_reg mux_2_reg_i (
        .i_from_data_mem(data_read), .i_from_alu(alu_out),
        .i_from_q_measure(i_q_measurement),
        .i_from_comp_flg({52'b0, comp_to_ctrl}),
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
        else if (opcode == 7'b0001000) end_reg <= 1'b1; // STOP instruction
    end
    assign end_sig = {63'b0, end_reg};

    // VLIW Counter Logic
    logic [1:0] cnt;
    always_ff @(posedge clk) begin
        if (rst) cnt <= 2'd2;
        else if (s_vliw) cnt <= 2'd1;
        else if (cnt < 2'd2) cnt <= cnt + 1'b1;
    end
     assign q_vliw  = ((cnt < 2'd2 & cnt > 2'd0)|(s_vliw))? 1'b1:1'b0;

    // Outputs
    assign q_inst       = (q_inst_sign || opcode[6] || q_vliw) ? instruction : 64'b0;
    assign q_time_reg   = time_reg_en ? rs_data : 64'b0;
    assign meas_rd_addr = {2'b0, instruction[2:0]};
    assign pram_en      = start_sig[0] & ~end_reg;
    assign pram_rd_en   = start_sig[0] & ~end_reg;
    assign pram_addr    = pc_val[10:0];
    assign dram_en      = start_sig[0] & ~end_reg;
    assign dram_rd_en   = start_sig[0] & ~end_reg;
    assign dram_wr_en   = mem_write;
    assign dram_addr    = alu_out[10:0];
    assign dram_din     = rs_data;

endmodule
