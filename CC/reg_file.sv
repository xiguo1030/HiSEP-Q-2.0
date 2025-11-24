//////////////////////////////////////////////////////////////////////////////////
// Company: TUM
// Engineer: QK
//
// Create Date: 2023/02/07 17:20:36
// Design Name:
// Module Name: reg_file
// Project Name:
// Target Devices:
// Tool Versions:
// Description: dual ports for reading and single port for writing
//
// Dependencies: License MIT
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
/// r0 is always 0, like riscv//////

`timescale 1ns / 1ps

module reg_file (
    input  logic        clk,
    input  logic        reset,
    input  logic [4:0]  rs_addr,
    input  logic [4:0]  rt_addr,
    input  logic [4:0]  wr_addr,
    input  logic [63:0] wr_data,
    input  logic        wr_en,
    output logic [63:0] rs_data,
    output logic [63:0] rt_data
);

    logic [63:0] regs [31:0];

    // 初始化 (仅用于仿真)
    initial begin
        for (int i=0; i<32; i++) regs[i] = 64'h0;
    end

    // 写逻辑 (同步)
    always_ff @(posedge clk) begin
        if (wr_en && (wr_addr != 0)) begin // R0 永远为 0
            regs[wr_addr] <= wr_data;
        end
    end

    // 读逻辑 (异步/组合逻辑，符合单周期设计)
    assign rs_data = (rs_addr == 0) ? '0 : regs[rs_addr];
    assign rt_data = (rt_addr == 0) ? '0 : regs[rt_addr];

endmodule
