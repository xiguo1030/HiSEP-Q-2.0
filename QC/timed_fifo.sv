module timed_fifo (
    input  logic        clk,
    input  logic        reset,
    input  logic [19:0] i_fifo_time,
    input  logic [17:0] i_fifo_op,
    input  logic        i_fifo_we,
    input  logic [19:0] t_cnt,
    output logic [17:0] o_data,
    output logic        error,
    output logic        o_data_wr_en,
    output logic [10:0] o_data_mem_addr
);

    parameter DEPTH      = 8;
    parameter DATA_WIDTH = 38;

    logic [37:0] i_fifo_din;
    logic        fifo_rd_en;
    logic [37:0] fifo_dout;
    logic        fifo_empty;
    logic        fifo_full;

    assign error      = fifo_full;
    assign i_fifo_din = {i_fifo_time, i_fifo_op};

    inst_fifo #(
        .DEPTH(DEPTH), .DATA_WIDTH(DATA_WIDTH)
    ) inst_fifo_i (
        .clk(clk), .reset(reset),
        .wr_en(i_fifo_we), .rd_en(fifo_rd_en),
        .data_in(i_fifo_din), .data_out(fifo_dout),
        .full(fifo_full), .empty(fifo_empty)
    );

    time_controller time_controller_i (
        .clk(clk), .reset(reset),
        .t_cnt(t_cnt),
        .fifo_rd_en(fifo_rd_en),
        .fifo_data(fifo_dout),
        .fifo_empty(fifo_empty),
        .o_data(o_data),
        .o_data_wr_en(o_data_wr_en),
        .o_data_mem_addr(o_data_mem_addr)
    );

endmodule
