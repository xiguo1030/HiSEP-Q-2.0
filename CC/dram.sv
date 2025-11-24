module dram (
    input  logic        clk,
    input  logic        ena,
    input  logic        rea,
    input  logic        wea,
    input  logic        reset,
    input  logic [10:0] addra,
    input  logic [63:0] dia,
    output logic [63:0] doa
);

    logic [63:0] DRAM [0:15]; // Depth 16 (2**4)

    initial begin
        $readmemh("./init_data_bram.mem", DRAM);
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
