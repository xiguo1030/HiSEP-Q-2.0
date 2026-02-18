module dram (
    input  logic        clk,
    input  logic        ena,
    input  logic        rea,
    input  logic        wea,
    input  logic        reset,
    input  logic [10:0] addra,
    input  logic [31:0] dia, // CHANGED
    output logic [31:0] doa  // CHANGED
);
    logic [31:0] DRAM [0:15]; // CHANGED

    initial begin
        $readmemh("./init_data_bram.mem", DRAM); // 确保数据初始化文件也是32bit宽
    end

    // Write Logic
    always_ff @(posedge clk) begin
        if (ena && wea) begin
            DRAM[addra] <= dia;
        end
    end

    // Read Logic
    always_ff @(posedge clk) begin
        if (reset)          doa <= '0;
        else if (ena & rea) doa <= DRAM[addra];
    end

endmodule