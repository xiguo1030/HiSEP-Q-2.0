`include "../parameter.v"

module alu (
    input  logic [31:0] op_A,    // 32-bit
    input  logic [31:0] op_B,    // 32-bit
    input  logic [3:0]  ALU_op,
    output logic [31:0] result,  // 32-bit
    output logic [9:0]  comp_flag
);
    logic [31:0] add_out, and_out, or_out, xor_out, not_out;
    logic [32:0] add_A, add_B; // 32+1 bits for overflow calc
    logic        sub_op;
    // 比较信号
    logic        equal, less_us, less_s;
    
    // --- 1. ALU ---
    assign sub_op = (ALU_op == `SUB) || (ALU_op == `CMP);

    // 构建加法器输入
    assign add_A = {op_A, 1'b1};
    assign add_B = sub_op ? {~op_B, 1'b1} : {op_B, 1'b0};
    // 加法结果 (取高32位)
    assign add_out = (add_A + add_B) >> 1;

    // 位运算
    assign and_out = op_A & op_B;
    assign or_out  = op_A | op_B;
    assign xor_out = op_A ^ op_B;
    assign not_out = ~op_B;

    // --- 2. 结果选择 (组合逻辑) ---
    always_comb begin
        unique case(ALU_op)
            `AND:    result = and_out;
            `OR:     result = or_out;
            `NOT:    result = not_out;
            `XOR:    result = xor_out;
            default: result = add_out;
        endcase
    end

    // --- 3. 比较标志位生成 ---
    assign equal   = (op_A == op_B);
    assign less_us = (op_A < op_B);

    // 有符号小于判断 (Check bit 31)
    always_comb begin
        if (op_A[31] != op_B[31]) 
            less_s = op_A[31]; // 符号不同，负数(1)肯定更小
        else 
            less_s = result[31]; // 符号相同，看减法结果符号位
    end

    // 生成10位比较标志
    always_comb begin
        comp_flag[0] = (!less_s) & (!equal); // GT (S)
        comp_flag[1] = less_s | equal;       // LE (S)
        comp_flag[2] = (!less_s) | equal;    // GE (S)
        comp_flag[3] = less_s & (!equal);    // LT (S)
        comp_flag[4] = (!less_us) & (!equal);// GT (U)
        comp_flag[5] = less_us | equal;      // LE (U)
        comp_flag[6] = (!less_us) | equal;   // GE (U)
        comp_flag[7] = less_us & (!equal);   // LT (U)
        comp_flag[8] = !equal;               // NE
        comp_flag[9] = equal;                // EQ
    end

endmodule