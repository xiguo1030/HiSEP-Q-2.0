`include "../parameter.v"

module alu (
    input  logic [63:0] op_A,    // from rt
    input  logic [63:0] op_B,    // from rs 或 imm
    input  logic [3:0]  ALU_op,
    output logic [63:0] result,
    output logic [9:0]  comp_flag
);

    logic [63:0] add_out, and_out, or_out, xor_out, not_out;
    logic [64:0] add_A, add_B; // extending one bit for overflow
    logic        sub_op;
    
    // 比较信号
    logic        equal, less_us, less_s;
    logic [63:0] op_A_unsign, op_B_unsign;

    assign op_A_unsign = op_A;
    assign op_B_unsign = op_B;

    // --- 1. ALU ---
    // 判断是否为减法或比较 (CMP 本质也是减法)
    assign sub_op = (ALU_op == `SUB) || (ALU_op == `CMP);

    // 构建加法器输入：如果是减法，执行 A + (~B) + 1
    assign add_A = {op_A, 1'b1}; 
    assign add_B = sub_op ? {~op_B, 1'b1} : {op_B, 1'b0};
    
    // 加法结果 (取高64位)
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
            default: result = add_out; // ADD, SUB, CMP, LD, ST 都用加法器
        endcase
    end

    // --- 3. 比较标志位生成 ---
    assign equal   = (op_A == op_B);
    assign less_us = (op_A < op_B);

    // 有符号小于判断
    always_comb begin
        if (op_A[63] != op_B[63]) 
            less_s = op_A[63]; // 符号不同，负数(1)肯定更小
        else 
            less_s = result[63]; // 符号相同，看减法结果符号位
    end

    // 生成10位比较标志 (对应你的ISA定义)
    always_comb begin
        comp_flag[0] = (!less_s) & (!equal); // GT (Signed)
        comp_flag[1] = less_s | equal;       // LE (Signed)
        comp_flag[2] = (!less_s) | equal;    // GE (Signed)
        comp_flag[3] = less_s & (!equal);    // LT (Signed)
        comp_flag[4] = (!less_us) & (!equal);// GT (Unsigned)
        comp_flag[5] = less_us | equal;      // LE (Unsigned)
        comp_flag[6] = (!less_us) | equal;   // GE (Unsigned)
        comp_flag[7] = less_us & (!equal);   // LT (Unsigned)
        comp_flag[8] = !equal;               // NE
        comp_flag[9] = equal;                // EQ
    end

endmodule
