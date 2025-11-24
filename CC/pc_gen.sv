module pc_gen (
    input  logic        clk,
    input  logic        reset,
    input  logic        i_sel_pc,    // Branch/Jump flag
    input  logic        start_sig,
    input  logic        end_sig,
    input  logic [63:0] i_pc_from_alu,
    output logic [63:0] o_pc
);
    logic [63:0] next_pc;

    // 1. 时序逻辑：更新 PC
    always_ff @(negedge clk) begin // 保持你原设计的 negedge
        if (reset)          
            o_pc <= '0;
        else if (start_sig) 
            o_pc <= next_pc;
        // else hold
    end

    // 2. 组合逻辑：计算 Next PC
    always_comb begin
        if (end_sig) begin
            next_pc = o_pc; // 停止
        end else if (i_sel_pc) begin
            next_pc = i_pc_from_alu; // 跳转/分支 (ALU计算出的地址)
        end else begin
            next_pc = o_pc + 64'd1; // 顺序执行 (PC+1)
        end
    end
endmodule
