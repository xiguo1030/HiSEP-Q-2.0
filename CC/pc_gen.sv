module pc_gen (
    input  logic        clk,
    input  logic        reset,
    input  logic        i_sel_pc,
    input  logic        start_sig,
    input  logic        end_sig,
    input  logic [31:0] i_pc_from_alu, // 32-bit
    output logic [31:0] o_pc           // 32-bit
);
    logic [31:0] next_pc;

    // 1. 时序逻辑：更新 PC
    always_ff @(negedge clk) begin 
        if (reset)          
            o_pc <= '0;
        else if (start_sig) 
            o_pc <= next_pc;
    end

    // 2. 组合逻辑：计算 Next PC
    always_comb begin
        if (end_sig) begin
            next_pc = o_pc;
        end else if (i_sel_pc) begin
            next_pc = i_pc_from_alu;
        end else begin
            next_pc = o_pc + 32'd1; // PC+1 (Word Addressed)
        end
    end
endmodule