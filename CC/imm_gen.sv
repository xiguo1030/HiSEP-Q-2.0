`include "../parameter.v"

module imm_gen (
    input  logic [31:0] instr,   // 32-bit Instruction
    input  logic [2:0]  imm_sel,
    input  logic [31:0] i_regs,  // 32-bit Rs data
    output logic [31:0] imm_out  // 32-bit Output
);

    logic [31:0] imm_i, imm_s, imm_br, imm_j, imm_ldi, imm_ldui, imm_qw;
    
    // 1. I-Type (LD): Imm12 [31:20] -> Sign Ext 32
    assign imm_i = {{20{instr[31]}}, instr[31:20]};

    // 2. S-Type (ST): Imm12 [31:25] | [11:7] -> Sign Ext 32
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    // 3. BR (Custom): Imm20 [31:12] -> Sign Ext 32
    assign imm_br = {{12{instr[31]}}, instr[31:12]};

    // 4. JUMP (Custom): Imm25 [31:7] -> Sign Ext 32
    assign imm_j = {{7{instr[31]}}, instr[31:7]};

    // 5. LDI: Imm20 [31:12] -> Sign Ext 32
    assign imm_ldi = {{12{instr[31]}}, instr[31:12]};

    // 6. LDUI: {Imm15 [31:17], Rs[16:0]} -> 32-bit
    assign imm_ldui = {instr[31:17], i_regs[16:0]};

    // 7. QWAIT: Imm20 [31:12] -> Zero Ext 32
    assign imm_qw = {12'b0, instr[31:12]};

    always_comb begin
        case (imm_sel)
            `IMM_I:    imm_out = imm_i;
            `IMM_S:    imm_out = imm_s;
            `IMM_BR:   imm_out = imm_br;
            `IMM_J:    imm_out = imm_j;
            `IMM_LDI:  imm_out = imm_ldi;
            `IMM_LDUI: imm_out = imm_ldui;
            `IMM_QW:   imm_out = imm_qw;
            default:   imm_out = '0;
        endcase
    end

endmodule