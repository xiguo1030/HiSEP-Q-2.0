module pram (
    input  logic        clk,
    input  logic        ena,
    input  logic        rea,
    input  logic        reset,
    input  logic [10:0] addr, // 11 bits
    output logic [63:0] program_out
);

    logic [63:0] PRAM [0:31]; // Depth 32

    initial begin
        $readmemh("./init_instr.mem", PRAM);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            program_out <= '0;
        end else if (ena & rea) begin
            program_out <= PRAM[addr];
        end
    end

endmodule
