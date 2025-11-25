`timescale 1ns / 1ps
`include "../parameter.v"

module quantum_ctrl #(
    parameter integer NCH = 110,
    parameter DEPTH = 32,
    parameter DATA_WIDTH = 20
)(
    input  logic        clk,
    input  logic        reset,
    input  logic [63:0] q_instruction, // Matches classical_ctrl 'q_inst'
    input  logic [63:0] i_register,    // Matches classical_ctrl 'q_time_reg'
    input  logic        q_vliw,
    input  logic        q_slm,
    input  logic        q_rot,
    input  logic        q_time_sel,
    input  logic        q_time_write,
    input  logic [1:0]  q_reg_write,
    input  logic [19:0] t_cnt,

    output logic [20*NCH-1:0] abs_time,
    output logic [NCH-1:0]    fifo_wr_en,
    output logic [18*NCH-1:0] fifo_wd,
    output logic [NCH-1:0]    err_bit
);

    // --- Internal Signals ---
    // Decoder outputs
    logic [19:0] timing;
    logic [2:0]  pi;
    logic [4:0]  Si_addr, Ti_addr;
    logic [45:0] Si_reg_s;
    logic [13:0] Ti_reg_s;
    logic [63:0] Q_reg_l;
    logic [4:0]  Si_offset;
    logic [4:0]  q_reg_rd_addr1, q_reg_rd_addr2;
    logic [6:0]  q_opcode1, q_opcode2;
    logic [10:0] angle;

    // Timestamp Manager signals
    logic [19:0] o_tstamp_time;
    logic        o_tstamp_full, o_tstamp_empty;
    logic        tstamp_rd_en;

    // Control LUT outputs
    logic [4:0]  o_q_op1, o_q_op2;
    logic        o_meas_write_en1, o_meas_write_en2;
    logic        o_tstamp_rd_en1, o_tstamp_rd_en2;
    logic [1:0]  o_q_op_sel1, o_q_op_sel2;
    logic        meas_wr_en;

    // Register File Mux signals
    logic [4:0]  i_ARd_Rs1, i_ARd_Rs2, i_ARd_Rt1, i_ARd_Rt2;
    logic [4:0]  o_DRd_Ro1, o_DRd_Ro2;
    logic [45:0] o_DRd_Rs1_s, o_DRd_Rs2_s;
    logic [109:0]o_DRd_Rs1_l, o_DRd_Rs2_l;
    logic [10:0] o_angle1, o_angle2;
    logic [13:0] o_DRd_Rt1_s, o_DRd_Rt2_s;
    logic [104:0]o_DRd_Rt1_l, o_DRd_Rt2_l;

    // Reg Decoder outputs
    logic [219:0] q_reg_rd_data1, q_reg_rd_data2;

    // Instruction Combination Buffer
    logic [52+NCH*4-1:0] inst_comb;

    // Pipeline Registers
    logic [219:0] r_reg_rd_data1, r_reg_rd_data2;
    logic [4:0]   r_q_op1, r_q_op2;
    logic [2:0]   time_offset;
    logic [10:0]  r_angle1, r_angle2;
    logic         r_tstamp_empty;

    // --- Combinational Logic ---
    assign meas_wr_en   = o_meas_write_en1 | o_meas_write_en2;
    assign tstamp_rd_en = o_tstamp_rd_en1  | o_tstamp_rd_en2;

    assign i_ARd_Rs1 = o_q_op_sel1[0] ? q_reg_rd_addr1 : 5'b0;
    assign i_ARd_Rs2 = o_q_op_sel2[0] ? q_reg_rd_addr2 : 5'b0;
    assign i_ARd_Rt1 = o_q_op_sel1[1] ? q_reg_rd_addr1 : 5'b0;
    assign i_ARd_Rt2 = o_q_op_sel2[1] ? q_reg_rd_addr2 : 5'b0;

    // --- Sequential Logic ---
    always_ff @(posedge clk) begin
        if (reset) begin
            r_reg_rd_data1 <= '0;
            r_reg_rd_data2 <= '0;
            r_q_op1        <= '0;
            r_q_op2        <= '0;
            r_angle1       <= '0;
            r_angle2       <= '0;
            time_offset    <= '0;
            r_tstamp_empty <= 1'b0;
        end else begin
            r_reg_rd_data1 <= q_reg_rd_data1;
            r_reg_rd_data2 <= q_reg_rd_data2;
            r_q_op1        <= o_q_op1;
            r_q_op2        <= o_q_op2;
            r_angle1       <= o_angle1;
            r_angle2       <= o_angle2;
            time_offset    <= pi;
            r_tstamp_empty <= o_tstamp_empty;
        end
    end

    // --- Module Instantiations ---

    q_decoder q_decoder_i (
        .q_instruction  (q_instruction),
        .i_register     (i_register),
        .q_time_sel     (q_time_sel),
        .t_cnt          (t_cnt),
        .timing         (timing),
        .pi             (pi),
        .Si_addr        (Si_addr),
        .Ti_addr        (Ti_addr),
        .Si_reg_s       (Si_reg_s),
        .Ti_reg_s       (Ti_reg_s),
        .Q_reg_l        (Q_reg_l),
        .Si_offset      (Si_offset),
        .angle          (angle),
        .q_reg_rd_addr1 (q_reg_rd_addr1),
        .q_reg_rd_addr2 (q_reg_rd_addr2),
        .q_opcode1      (q_opcode1),
        .q_opcode2      (q_opcode2)
    );

    q_time_manager #(
        .DEPTH(DEPTH), .DATA_WIDTH(DATA_WIDTH)
    ) q_time_manager_dut (
        .clk(clk), .reset(reset),
        .wr_en(q_time_write), .rd_en(tstamp_rd_en),
        .data_in(timing),
        .data_out(o_tstamp_time),
        .full(o_tstamp_full), .empty(o_tstamp_empty)
    );

    q_control_lut q_control_lut_1 (
        .q_opcode(q_opcode1),
        .q_op_sign(q_instruction[63]),
        .q_micro_op(o_q_op1),
        .meas_write_en(o_meas_write_en1),
        .timestamp_rd_en(o_tstamp_rd_en1),
        .q_op_sel(o_q_op_sel1)
    );

    q_control_lut q_control_lut_2 (
        .q_opcode(q_opcode2),
        .q_op_sign(q_instruction[63]),
        .q_micro_op(o_q_op2),
        .meas_write_en(o_meas_write_en2),
        .timestamp_rd_en(o_tstamp_rd_en2),
        .q_op_sel(o_q_op_sel2)
    );

    q_reg_single q_reg_single_i (
        .clk(clk), .reset(reset),
        .wr_addr(Si_addr), .q_slm(q_slm), .long_ind(q_vliw),
        .rd_addr1(i_ARd_Rs1), .rd_addr2(i_ARd_Rs2),
        .Si_offset(Si_offset), .wr_data_s(Si_reg_s), .wr_data_l(Q_reg_l),
        .wr_en(q_reg_write), .angle(angle), .q_rot(q_rot),
        .sd_offset1(o_DRd_Ro1), .sd_offset2(o_DRd_Ro2),
        .sd_data1_s(o_DRd_Rs1_s), .sd_data2_s(o_DRd_Rs2_s),
        .sd_data1_l(o_DRd_Rs1_l), .sd_data2_l(o_DRd_Rs2_l),
        .sd_angle1(o_angle1), .sd_angle2(o_angle2)
    );

    q_reg_double q_reg_double_i (
        .clk(clk), .reset(reset),
        .wr_addr(Ti_addr), .long_ind(q_vliw),
        .rd_addr1(i_ARd_Rt1), .rd_addr2(i_ARd_Rt2),
        .wr_data_s(Ti_reg_s), .wr_data_l(Q_reg_l),
        .wr_en(q_reg_write),
        .sd_data1_s(o_DRd_Rt1_s), .sd_data2_s(o_DRd_Rt2_s),
        .sd_data1_l(o_DRd_Rt1_l), .sd_data2_l(o_DRd_Rt2_l)
    );

    q_reg_decoder q_reg_decoder_1 (
        .sreg_data_s(o_DRd_Rs1_s), .sreg_data_l(o_DRd_Rs1_l),
        .treg_data_s(o_DRd_Rt1_s), .treg_data_l(o_DRd_Rt1_l),
        .reg_off(o_DRd_Ro1), .reg_read_addr(q_reg_rd_addr1),
        .q_reg_sel(o_q_op_sel1), .q_op_out(q_reg_rd_data1)
    );

    q_reg_decoder q_reg_decoder_2 (
        .sreg_data_s(o_DRd_Rs2_s), .sreg_data_l(o_DRd_Rs2_l),
        .treg_data_s(o_DRd_Rt2_s), .treg_data_l(o_DRd_Rt2_l),
        .reg_off(o_DRd_Ro2), .reg_read_addr(q_reg_rd_addr2),
        .q_reg_sel(o_q_op_sel2), .q_op_out(q_reg_rd_data2)
    );

    // 假设 q_instr_comb 模块存在，接口需匹配
    q_instr_comb #(.NCH(NCH)) q_instr_comb_dut (
        .clk(clk), .reset(reset),
        .oprand_1(r_q_op1), .oprand_2(r_q_op2),
        .qubit_address1(r_reg_rd_data1), .qubit_address2(r_reg_rd_data2),
        .time_reg(o_tstamp_time), .time_offset(time_offset),
        .time_fifo_empty(r_tstamp_empty),
        .inst_comb(inst_comb),
        .angle_1(r_angle1), .angle_2(r_angle2)
    );

    dispatcher #(.NCH(NCH)) dispatcher_dut (
        .clk(clk), .reset(reset),
        .comb(inst_comb),
        .abs_time(abs_time),
        .fifo_wr_en(fifo_wr_en),
        .fifo_wd(fifo_wd),
        .err_bit(err_bit)
    );

endmodule
