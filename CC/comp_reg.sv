`include "../parameter.v"

module comp_reg (
    input  logic        clk,
    input  logic        reset,
    input  logic [9:0]  i_comp_flag,
    input  logic [3:0]  ALU_op,
    output logic [11:0] o_comp_reg
);


logic [11:0] flags;

    always_ff @(posedge clk) begin
        if (reset) begin
            // 复位状态：
            // Bit 11 (Always) = 1
            // Bit 10 (Never)  = 0
            // Bit 9-0 (Flags) = 0 (或者其他初始值)
            flags <= 12'h800; // 1000_0000_0000
        end else begin
            // 只有在执行 CMP 指令时，才更新寄存器
            if (ALU_op == `CMP) begin
                // 拼接逻辑
                // { Always(1), Never(0), ALU_Flags[9:0] }
                flags <= {1'b1, 1'b0, i_comp_flag};
            end
        end
    end

    // 输出
    assign o_comp_reg = flags;
endmodule
