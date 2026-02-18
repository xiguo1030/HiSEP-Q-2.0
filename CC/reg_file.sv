//////////////////////////////////////////////////////////////////////////////////
// Company: TUM
// Engineer: QK
// 
// Description: dual ports for reading and single port for writing (32-bit version)
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module reg_file (
    input  logic        clk,
    input  logic        reset, // 现在这个信号会被使用了
    input  logic [4:0]  rs_addr,
    input  logic [4:0]  rt_addr,
    input  logic [4:0]  wr_addr,
    input  logic [31:0] wr_data,
    input  logic        wr_en,
    output logic [31:0] rs_data,
    output logic [31:0] rt_data
);
    logic [31:0] regs [0:31];

    initial begin
        for (int i=0; i<32; i++) regs[i] = 32'h0;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            // 硬件复位：清空所有寄存器
            for (int i=0; i<32; i++) regs[i] <= 32'h0;
        end else if (wr_en && (wr_addr != 0)) begin
            regs[wr_addr] <= wr_data;
        end
    end

    assign rs_data = (rs_addr == 0) ? 32'b0 : regs[rs_addr];
    assign rt_data = (rt_addr == 0) ? 32'b0 : regs[rt_addr];

endmodule