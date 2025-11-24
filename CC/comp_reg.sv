`include "../parameter.v"

module comp_reg (
    input  logic        clk,
    input  logic        reset,
    input  logic [9:0]  i_comp_flag,
    input  logic [3:0]  ALU_op,
    output logic [11:0] o_comp_reg
);

    always_ff @(posedge clk) begin
        if (reset) begin
            // Bit 11=Always(1), Bit 10=Never(0), 后面接 ALU flag
            o_comp_reg <= {1'b1, 1'b0, 10'b0}; 
        end else if (ALU_op == `CMP) begin
            o_comp_reg <= {1'b1, 1'b0, i_comp_flag};
        end
        // else hold
    end
endmodule
