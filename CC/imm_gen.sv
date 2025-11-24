`include "../parameter.v"

module imm_gen (
    input  logic [24:0] imm_src,
    input  logic [2:0]  imm_sel,
    input  logic [63:0] i_regs,
    output logic [63:0] imm_out
);
    // 定义内部信号
    logic [63:0] imm_M, imm_BR, imm_LDI, imm_LDUI;
    logic        sign_bit_st;
    logic        sign_bit_ldi;
    logic [9:0]  inst_m;
    logic [19:0] inst_ldi;
    logic [14:0] inst_ldui;
    logic [20:0] inst_br_raw;
    logic [16:0] inst_br_mixed;

    // --- 关键修改：使用 assign 进行连续赋值 ---
    assign sign_bit_st = imm_src[9];
    assign sign_bit_ldi = imm_src[19];
    
    assign inst_m      = imm_src[9:0];
    assign inst_ldi    = imm_src[19:0];
    assign inst_ldui   = imm_src[14:0];
    assign inst_br_raw = imm_src[24:4];

    // 分类生成逻辑
    assign imm_M    = {{54{sign_bit_st}}, inst_m};   // 符号扩展
    assign imm_LDI  = {{44{sign_bit_ldi}}, inst_ldi};
    
    // LDUI: 拼接 imm15 和 寄存器低17位 (参考原逻辑)
    assign imm_LDUI = {32'b0, inst_ldui, i_regs[16:0]}; 

    // Branch Imm: 位拼接
    assign inst_br_mixed = {inst_br_raw[12], 4'b0, inst_br_raw[11:0]};
    assign imm_BR   = {{47{1'b0}}, inst_br_mixed};

    // 输出选择 MUX
    always_comb begin
        case (imm_sel)
            `IMM_M:    imm_out = imm_M;
            `IMM_BR:   imm_out = imm_BR;
            `IMM_LDI:  imm_out = imm_LDI;
            `IMM_LDUI: imm_out = imm_LDUI;
            default:   imm_out = '0;
        endcase
    end

endmodule