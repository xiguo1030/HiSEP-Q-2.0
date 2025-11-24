//////////////////////////////////////////////////////////////////////////////////
// Company: TUM
// Engineer: Xiaorang
//
// Create Date: 2023/02/08
// Design Name:
// Module Name: mux_alu_a
// Project Name:
// Target Devices:
// Tool Versions:
// Description: mux before the op_a of ALU, if the operation is branch, input is PC(plus imm in ALU), other wise, input is reg
//
// Dependencies: License Apache 2.0
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
// --- MUX ALU A ---
`include "../parameter.v"
module mux_alu_a (
    input  logic [63:0] i_reg,
    input  logic [63:0] i_pc,
    input  logic        i_branch_sel, 
    output logic [63:0] o_alu_a
);
    always_comb begin
        if (i_branch_sel == `PC_JUMP) 
            o_alu_a = i_pc;
        else 
            o_alu_a = i_reg;
    end
endmodule

// --- MUX ALU B ---
module mux_alu_b (
    input  logic [63:0] i_reg,
    input  logic [63:0] i_imm,
    input  logic        i_imm_sel, 
    output logic [63:0] o_alu_b
);
    always_comb begin
        if (i_imm_sel) o_alu_b = i_imm;
        else           o_alu_b = i_reg;
    end
endmodule

// --- MUX TO REGISTER FILE ---
module mux_2_reg (
    input  logic [63:0] i_from_data_mem,
    input  logic [63:0] i_from_alu,
    input  logic [63:0] i_from_q_measure,
    input  logic [63:0] i_from_comp_flg,
    input  logic [63:0] i_from_imm,
    input  logic [2:0]  sel_from_ctrl,
    output logic [63:0] o_2_regfile
);
    always_comb begin
        case (sel_from_ctrl)
            `REGSRC_MEM:  o_2_regfile = i_from_data_mem;
            `REGSRC_ALU:  o_2_regfile = i_from_alu;
            `REGSRC_MEA:  o_2_regfile = i_from_q_measure;
            `REGSRC_COMP: o_2_regfile = i_from_comp_flg;
            `REGSRC_IMM:  o_2_regfile = i_from_imm;
            default:      o_2_regfile = i_from_alu;
        endcase
    end
endmodule
