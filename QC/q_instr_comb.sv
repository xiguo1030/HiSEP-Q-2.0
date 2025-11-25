module q_instr_comb #(parameter integer NCH = 110) (
    input  logic        clk,
    input  logic        reset,
    input  logic [4:0]  oprand_1,
    input  logic [4:0]  oprand_2,
    
    // 【修复 1】参数化端口宽度
    // 每个量子比特对应 2 位操作码，所以总宽是 2 * NCH
    input  logic [2*NCH-1:0] qubit_address1,
    input  logic [2*NCH-1:0] qubit_address2,
    
    input  logic [19:0] time_reg,
    input  logic [2:0]  time_offset,
    input  logic        time_fifo_empty,
    
    // 【修复 2】参数化输出宽度
    // 计算公式：
    // 20 (time) + 5 (op1) + 2*NCH (addr1) + 11 (ang1) + 5 (op2) + 2*NCH (addr2) + 11 (ang2)
    // = 20 + 5 + 11 + 5 + 11 + 4*NCH 
    // = 52 + 4*NCH
    output logic [52+4*NCH-1:0] inst_comb,
    
    input  logic [10:0] angle_1,
    input  logic [10:0] angle_2
);

    logic [19:0] time_abs;

    // 时间计算逻辑
    assign time_abs = time_fifo_empty ? {17'b0, time_offset} : (time_reg + time_offset);

    // 指令拼接逻辑
    always_ff @(posedge clk) begin
        if (reset) begin
            inst_comb <= '0;
        end else begin
            // 【修复 3】直接拼接，SystemVerilog 会根据位宽自动处理
            // 结构：Time | Op1 | Addr1 | Ang1 | Op2 | Addr2 | Ang2
            inst_comb <= {
                time_abs, 
                oprand_1, 
                qubit_address1, 
                angle_1, 
                oprand_2, 
                qubit_address2, 
                angle_2
            };
        end
    end

endmodule