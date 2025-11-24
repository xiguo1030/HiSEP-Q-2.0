//module clk_inverter(
//    input  logic clk,
//    input  logic reset,
//    output logic inverted_clk
//);
//    logic inverted_clk_p;
//    logic inverted_clk_n;

//    // Negedge toggle
//    always_ff @(negedge clk) begin
//        if (reset) inverted_clk_n <= 0;
//        else       inverted_clk_n <= ~inverted_clk_n;
//    end
    
//    // Posedge toggle
//    always_ff @(posedge clk) begin
//        if (reset) inverted_clk_p <= 0;
//        else       inverted_clk_p <= ~inverted_clk_p;
//    end
    
//    // XOR Output
//    assign inverted_clk = (reset) ? 1'b0 : (inverted_clk_n ^ inverted_clk_p);

//endmodule

module clk_inverter(
    input  logic clk,
    input  logic reset,
    output logic inverted_clk
);

    // 最简单、最可靠的反相方式
    // 如果 reset 有效，输出 0；否则输出 ~clk
    // 注意：具体的复位行为看你需求，通常时钟反相器不需要复位逻辑，直接 assign inverted_clk = ~clk 即可
    // 但为了保持和你原接口一致：
    
    assign inverted_clk = reset ? 1'b0 : ~clk;

endmodule
