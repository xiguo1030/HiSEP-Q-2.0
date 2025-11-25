`timescale 1ns / 1ps
module tb_quantum_ctrl;

    // Parameters
    localparam DEPTH      = 32;
    localparam DATA_WIDTH = 20;
    localparam PERIOD     = 100;

    // Signals
    logic        clk   = 0;
    logic        reset = 0;
    
    // Inputs to DUT
    logic [63:0] q_instruction = 64'b0; 
    logic [63:0] i_register    = 64'b0; 
    logic        q_time_sel    = 0;
    logic        q_time_write  = 0;
    logic [1:0]  q_reg_write   = 2'b0;
    
    // Additional control signals
    logic        q_vliw        = 0;
    logic        q_slm         = 0;
    logic        q_rot         = 0;
    logic [19:0] t_cnt         = 20'b0; 

    // Outputs from DUT
    localparam NCH = 7;
    
    logic [20*NCH-1:0] abs_time;
    logic [NCH-1:0]    fifo_wr_en;
    logic [18*NCH-1:0] fifo_wd;
    logic [NCH-1:0]    err_bit;

    // DUT Instantiation
    quantum_ctrl #(
        .NCH(NCH),
        .DEPTH(DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .q_instruction(q_instruction),
        .i_register(i_register),
        .q_vliw(q_vliw),
        .q_slm(q_slm),
        .q_rot(q_rot),
        .q_time_sel(q_time_sel),
        .q_time_write(q_time_write),
        .q_reg_write(q_reg_write),
        .t_cnt(t_cnt),
        .abs_time(abs_time),
        .fifo_wr_en(fifo_wr_en),
        .fifo_wd(fifo_wd),
        .err_bit(err_bit)
    );

    // Clock
    initial clk = 1'b1;
    always #(PERIOD/2.0) clk = !clk;

    // Timer
    always @(posedge clk) begin
        if (reset) t_cnt <= 0;
        else       t_cnt <= t_cnt + 1;
    end

    // Helper Task
    task send_op(input [63:0] inst, input [1:0] reg_wr = 0, input time_wr = 0, input time_sel = 0);
        q_instruction <= inst;
        q_reg_write   <= reg_wr;
        q_time_write  <= time_wr;
        q_time_sel    <= time_sel;
        #(PERIOD*1); 
    endtask

    // Main Test
    initial begin
        $display("=== Quantum Control Verification Start ===");
        
        // 1. Reset
        reset = 1;
        #(PERIOD*2);
        reset = 0;
        #(PERIOD);

        // 2. SMIS (Single Mask Set) s7, {0,2}
        // ISA: 0(1)_Op(7)_Sd(5)_Offset(5)_Imm46(46) = 64 bits
        // Opcode SMSO: 1001000 (0x48)
        // Target: s7 (reg 7), Offset: 0, Mask: 5 (101)
        $display("[TEST] SMIS s7, {0,2}");
        q_slm = 1; 
        send_op({1'b0, 7'b1001000, 5'd7, 5'd0, 46'd5}, 2'b01); 
        q_slm = 0;

        // 测试用例 2: SITO (SMIT) - 配置双比特对
        // ------------------------------------------------------
        // 目标: t4 (Reg 4), Offset 0, Pair {1,4}
        // Opcode: 1001100 (0x4C)
        // Hex: 4C20000000000084
        $display("[TEST 2] SITO t4, offset 0, {1,4}");
        // 注意：置位 reg_wr=10
        send_op(64'h4C20000000000084, 2'b10);
        
        // 4. QWAIT 15
        // ISA: 0(1)_Op(7)_Reserved(36)_Imm20(20) = 64 bits
        // Opcode: 1000000 (0x40)
        $display("[TEST] QWAIT 15");
        send_op({1'b0, 7'b1000000, 36'b0, 20'd15}, 2'b00, 1'b1, 1'b1); 

        // 5. Y90 s7
        // ISA: 1(1)_Op1(7)_Si1(5)_Op2(7)_Si2(5)_Op3(7)_Si3(5)_Res(24)_PI(3) = 64 bits
        // Opcode Y90: 0x05
        // Op1=Y90, Si1=7. Others 0.
        $display("[TEST] Y90 s7 (Should fire on q0 and q2)");
        send_op({1'b1, 7'd5, 5'd7, 7'd0, 5'd0, 7'd0, 5'd0, 24'b0, 3'd0}); 
                // Wait for 5 clock cycles (NOPs/Idle) to allow pipeline latency
        repeat(2) begin
            q_instruction <= 64'b0; // Explicit NOP
            @(posedge clk);
        end
        // Check Outputs
        #(1); 
        if (fifo_wr_en[0] && fifo_wr_en[2]) 
            $display("[PASS] Y90 dispatched to Q0 and Q2");
        else 
            $display("[FAIL] Dispatch failed: wr_en=%b", fifo_wr_en);

        // 6. QWAITR 20
        // ISA: 0(1)_Op(7)_Reserved(56) = 64 bits
        $display("[TEST] QWAITR 20 (from Reg)");
        i_register = 64'd20;
        send_op({1'b0, 7'b1000001, 56'b0}, 2'b00, 1'b1, 1'b0); 

        // 7. Parallel: X90 s7 | CNOT t0
        // X90 (Op 2), CNOT (Op 16), PI=2
        // 7. Parallel: X90 s7 | CNOT t4
        // X90 (Op 2) on Q0,Q2 (from s7)
        // CNOT (Op 16) on Q1,Q4 (from t4)
        $display("[TEST 6] Parallel: X90 s7 | CNOT t4");
        // 1(1)_Op1(7)_Si1(5)_Op2(7)_Ti1(5)_Res(24)_PI(3) = 64 bits
        // Op1=2 (X90), Si1=7 (s7)
        // Op2=16 (CNOT), Ti1=4 (t4)
        send_op({1'b1, 7'd2, 5'd7, 7'd16, 5'd4, 7'd0, 5'd0, 24'b0, 3'd2});
        
        repeat(2) begin
            q_instruction <= 64'b0; // Explicit NOP
            @(posedge clk);
        end
       // Check specifically for t4's targets (Q1 and Q4)
        if (fifo_wr_en[1] && fifo_wr_en[4]) 
              $display("       Target Channels (1 and 4) Active (Success from t4).");
        else
              $display("       Target Channels MISSING! wr_en=%b", fifo_wr_en);

        #(PERIOD*10);
        $display("=== Verification Complete ===");
        $finish;
    end

endmodule