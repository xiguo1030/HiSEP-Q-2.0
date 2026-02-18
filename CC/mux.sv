`include "../parameter.v"

// --- MUX ALU A ---
module mux_alu_a (
    input  logic [31:0] i_reg,   // 32-bit
    input  logic [31:0] i_pc,    // 32-bit
    input  logic        i_branch_sel, 
    output logic [31:0] o_alu_a  // 32-bit
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
    input  logic [31:0] i_reg,   // 32-bit
    input  logic [31:0] i_imm,   // 32-bit
    input  logic        i_imm_sel, 
    output logic [31:0] o_alu_b  // 32-bit
);
    always_comb begin
        if (i_imm_sel) o_alu_b = i_imm;
        else           o_alu_b = i_reg;
    end
endmodule

// --- MUX TO REGISTER FILE ---
module mux_2_reg (
    input  logic [31:0] i_from_data_mem,  // 32-bit
    input  logic [31:0] i_from_alu,       // 32-bit
    input  logic [31:0] i_from_q_measure, // 32-bit
    input  logic [31:0] i_from_comp_flg,  // 32-bit
    input  logic [31:0] i_from_imm,       // 32-bit
    input  logic [2:0]  sel_from_ctrl,
    output logic [31:0] o_2_regfile       // 32-bit
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