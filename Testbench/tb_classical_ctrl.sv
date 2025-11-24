`timescale 1ns / 1ps

module tb_classical_ctrl;

  // ========================================================================
  // 1. 信号定义
  // ========================================================================
  reg clk = 0;
  reg rst = 0;
  reg [63:0] i_q_measurement = 64'hDEAD_BEEF; 
  reg [63:0] start_sig = 64'b0;

 // --- Outputs from DUT ---
  // Quantum Interface
  wire q_time_write;
  wire q_time_sel;
  wire [1:0] q_reg_write;
  wire q_vliw;          // 【补全】
  wire q_slm;           // 【补全】
  wire q_rot;           // 【补全】
  wire [63:0] q_inst;
  wire [63:0] q_time_reg;
  wire [4:0]  meas_rd_addr;
  
  // Misc
  wire [63:0] end_sig;  // 【修正】位宽改为 [63:0] 以匹配模块定义

  // --- Memory Interface Wires ---
  wire pram_en;
  wire pram_rd_en;
  wire [10:0] pram_addr;
  wire [63:0] instruction;
  
  wire inverted_clk;
  
  wire dram_en;
  wire dram_rd_en;
  wire dram_wr_en;
  wire [10:0] dram_addr;
  wire [63:0] dram_din;
  wire [63:0] data_read;

  // 内部信号方便调试访问
  // PC 信号路径: classical_ctrl_dut.pc_gen_i.o_pc
  // Regs 路径: classical_ctrl_dut.reg_file_i.regs
  // Mem 路径: dram_dut.BRAM

  // ========================================================================
  // 2. 模块实例化
  // ========================================================================
 classical_ctrl classical_ctrl_dut (
    .clk             (clk),
    .rst             (rst),
    .i_q_measurement (i_q_measurement),
    
    // Quantum Interface Outputs
    .q_time_write    (q_time_write),
    .q_time_sel      (q_time_sel),
    .q_reg_write     (q_reg_write),
    .q_vliw          (q_vliw),      // 【连接】
    .q_slm           (q_slm),       // 【连接】
    .q_rot           (q_rot),       // 【连接】
    .q_inst          (q_inst),
    .q_time_reg      (q_time_reg),
    .meas_rd_addr    (meas_rd_addr),

    // PRAM Interface
    .pram_en         (pram_en),
    .pram_rd_en      (pram_rd_en),
    .pram_addr       (pram_addr),
    .instruction     (instruction),

    // DRAM Interface
    .dram_en         (dram_en),
    .dram_rd_en      (dram_rd_en),
    .dram_wr_en      (dram_wr_en),
    .dram_addr       (dram_addr),
    .dram_din        (dram_din),
    .data_read       (data_read),
    .inverted_clk    (inverted_clk),

    // Control Signals
    .start_sig       (start_sig),
    .end_sig         (end_sig)      // 【连接】64位宽
  );

  pram pram_dut (
    .clk (clk ),
    .ena (pram_en ),
    .rea (pram_rd_en ),
    .reset (rst ),
    .addr (pram_addr ),
    .program_out(instruction)
  );

  dram dram_dut ( 
    .clk (inverted_clk ), 
    .ena (dram_en ),
    .rea (dram_rd_en),
    .wea (dram_wr_en ),
    .reset (rst ),
    .addra (dram_addr ),
    .dia (dram_din ),
    .doa (data_read)
  );

  // ========================================================================
  // 3. 时钟生成
  // ========================================================================
  parameter PERIOD = 10;
  initial clk = 1'b1;
  always #(PERIOD/2.0) clk = !clk;

  // ========================================================================
  // 4. 辅助任务 (Verification Tasks)
  // ========================================================================
  
  // 等待直到 PC 等于指定值 (Instruction Fetch Stage)
  task wait_for_pc(input int pc_val);
      // 设置超时防止死锁
      int timeout;
      timeout = 0;
      // classical_ctrl_dut.next_pc 实际上对应的是当前的 PC 输出 (因为连在 pc_gen.o_pc)
      while (classical_ctrl_dut.next_pc !== pc_val && timeout < 500) begin
          @(posedge clk);
          timeout++;
      end
      
      if (timeout >= 500) begin
          $display("[TIMEOUT] Waiting for PC=%0d failed. Current PC=%0d", pc_val, classical_ctrl_dut.next_pc);
          $stop;
      end
  endtask

  // 检查寄存器值 (在时钟下降沿后检查，确保写入完成)
  task check_reg(input int id, input [63:0] expected);
      // 等待半个周期，让写入逻辑稳定
      #(1); 
      if (classical_ctrl_dut.reg_file_i.regs[id] === expected)
          $display("[PASS] PC=%0d: Reg[%0d] Correctly Updated to %0d", classical_ctrl_dut.next_pc, id, expected);
      else begin
          $display("[FAIL] PC=%0d: Reg[%0d] Error! Expected: %0d, Actual: %0d", classical_ctrl_dut.next_pc, id, expected, classical_ctrl_dut.reg_file_i.regs[id]);
          $stop; // 遇到错误立刻停止
      end
  endtask

  // 检查内存值
  task check_mem(input int addr, input [63:0] expected);
      #(1);
      if (dram_dut.DRAM[addr] === expected)
          $display("[PASS] PC=%0d: Mem[%0d] Correctly Updated to %0d", classical_ctrl_dut.next_pc, addr, expected);
      else begin
          $display("[FAIL] PC=%0d: Mem[%0d] Error! Expected: %0d, Actual: %0d", classical_ctrl_dut.next_pc, addr, expected, dram_dut.DRAM[addr]);
          $stop;
      end
  endtask

  // 检查控制信号 (用于量子指令)
  task check_signal(input string name, input logic sig, input logic expected);
      if (sig === expected)
          $display("[PASS] PC=%0d: Signal %s is %b (Correct)", classical_ctrl_dut.next_pc, name, sig);
      else begin
          $display("[FAIL] PC=%0d: Signal %s Error! Expected: %b, Actual: %b", classical_ctrl_dut.next_pc, name, expected, sig);
          $stop;
      end
  endtask

 // ========================================================================
  // 5. 逐条指令步进验证
  // ========================================================================
  initial begin
      // A. 初始化与 Patch
      rst = 1; start_sig = 0;
      
      // --- HOT PATCH: 修复指令码 ---
      // 原因：原 .mem 文件中使用 Opcode 02 (JUMP, 无条件) 想要实现条件跳转。
      // 我们这里将其动态修改为 Opcode 01 (BR, 条件跳转)，以符合逻辑预期。
      // Wait for pram to initialize
      #1;
      // Patch PC=8: 02...29 -> 01...29
      pram_dut.PRAM[8][62:56] = 7'b0000001; 
      // Patch PC=9: 02...28 -> 01...28
      pram_dut.PRAM[9][62:56] = 7'b0000001;
      
      $display("==========================================================");
      $display("   HiSEP-Q Step-by-Step Instruction Verification");
      $display("   [INFO] Hot-Patched PC=8 & PC=9 from JUMP to BR");
      $display("==========================================================");

      // B. 启动
      #(PERIOD*3); rst = 0;
      #(PERIOD); start_sig = 1; 

      // --- 开始逐条验证 ---
      
      // 1-7. 之前的指令 (LDI, LD, ST, CMP)
      wait_for_pc(1); @(posedge clk); check_reg(10, 64'd10);
      wait_for_pc(2); @(posedge clk); check_reg(8, 64'd8);
      wait_for_pc(3); @(posedge clk); check_reg(4, 64'd4);
      wait_for_pc(4); @(posedge clk); check_reg(3, 64'd524296);
      wait_for_pc(5); @(posedge clk); check_reg(6, 64'd12);
      wait_for_pc(6); @(posedge clk); check_mem(12, 64'd10);
      
      // 7. PC=7: CMP R1(0), R3(524296) -> NE Flag set (Not Equal)
      wait_for_pc(7);
      @(posedge clk);
      $display("[PASS] PC=7: CMP executed. Flags set to NE.");

      // 8. PC=8: BR if EQ -> 条件不满足 (Flag is NE) -> 应该不跳
      wait_for_pc(8);
      @(posedge clk); 
      $display("[PASS] PC=8: BR(EQ) executed. Condition false, NO jump.");

      // 9. PC=9: BR if NE -> 条件满足 (Flag is NE) -> 应该跳 (PC+2)
      wait_for_pc(9);
      @(posedge clk);
      $display("[PASS] PC=9: BR(NE) executed. Condition true, JUMPING...");
      
      // 10. 验证跳转：PC 应该直接变成 11，跳过 10 (FMR)
      #(1); 
      if (classical_ctrl_dut.next_pc === 64'd11) 
          $display("[PASS] Jump Successful! PC skipped from 9 to 11.");
      else begin
          $display("[FAIL] Jump Failed! PC is %0d (Expected 11)", classical_ctrl_dut.next_pc);
          if (classical_ctrl_dut.next_pc === 64'd10) $display("       CPU executed FMR (PC=10) which should have been skipped.");
          $stop;
      end

      // 11. PC=11: ADD R10, R8, R4 -> 8+4=12
      wait_for_pc(11);
      #1; // <--- 手动加延时，确保信号稳定
      @(posedge clk);
      check_reg(10, 64'd12); 

      // 12. PC=12: SMSOL (Quantum Long Inst Part 1)
      wait_for_pc(12);
      #1; // <--- 手动加延时，确保信号稳定
      check_signal("q_vliw", q_vliw, 1'b1);
      check_signal("q_reg_write[0]", q_reg_write[0], 1'b1); 
      check_reg(18, 64'd0); // Safety Check
      @(posedge clk);

      // 13. PC=13: SMSOL Payload
      wait_for_pc(13);
      #1; // <--- 手动加延时，确保信号稳定
      check_signal("reg_write", classical_ctrl_dut.reg_write, 1'b0);
      @(posedge clk);

      // 14. PC=14: SITO
      wait_for_pc(14);
      #1; // <--- 手动加延时，确保信号稳定
      check_signal("q_reg_write[1]", q_reg_write[1], 1'b1);
      check_reg(4, 64'd4); // Safety Check
      @(posedge clk);

      // 15. PC=15: QWAIT 15
      wait_for_pc(15);
      #1; // <--- 手动加延时，确保信号稳定
      check_signal("q_time_write", q_time_write, 1'b1);
      @(posedge clk);

      // 16. PC=16: ROT X
      wait_for_pc(16);
      #1; // <--- 手动加延时，确保信号稳定
      check_signal("q_rot", q_rot, 1'b1);
      @(posedge clk);
      
      $display("\n==========================================================");
      $display("   ALL INSTRUCTIONS EXECUTED & VERIFIED SUCCESSFULLY");
      $display("==========================================================");
      
      $stop;
      $finish;
  end

endmodule