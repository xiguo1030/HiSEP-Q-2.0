module inst_fifo #(
    parameter DEPTH = 8,
    parameter DATA_WIDTH = 38
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        wr_en,
    input  logic        rd_en,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic        full,
    output logic        empty
);

    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    logic [DATA_WIDTH-1:0] data_out_reg;
    logic [$clog2(DEPTH):0] write_ptr;
    logic [$clog2(DEPTH):0] read_ptr;

    assign full  = ((write_ptr + 1'b1) == read_ptr);
    assign empty = (write_ptr == read_ptr);

    initial begin
        for (int i=0; i<DEPTH; i++) memory[i] = '0;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            write_ptr <= '0;
            read_ptr  <= '0;
            data_out_reg <= '0;
        end else begin
            if (wr_en && !full) begin
                memory[write_ptr[2:0]] <= data_in; // Assuming Depth 8 (3 bits)
                write_ptr <= write_ptr + 1'b1;
            end
            if (rd_en && !empty) begin
                data_out_reg <= memory[read_ptr[2:0]];
                read_ptr <= read_ptr + 1'b1;
            end
        end
    end

    assign data_out = data_out_reg;

endmodule
