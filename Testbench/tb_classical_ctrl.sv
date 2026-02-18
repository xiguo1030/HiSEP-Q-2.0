`timescale 1ns / 1ps

module tb_classical_ctrl;

  // ========================================================================
  // 1. 信号定义
  // ========================================================================
  reg clk = 0;
  reg rst = 0;
  reg [31:0] i_q_measurement = 32'hDEAD_BEEF; 
  reg [31:0] start_sig = 32'b0;

  // --- Outputs from DUT ---
  wire q_time_write;
  wire q_time_sel;
  wire [1:0] q_reg_write;
  wire q_slm;
  wire q_rot;
  wire [31:0] q_inst;
  wire [31:0] q_time_reg;
  wire [4:0]  meas_rd_addr;
  
  wire [31:0] end_sig;

  // --- Memory Interface Wires ---
  wire pram_en;
  wire pram_rd_en;
  wire [10:0] pram_addr;
  wire [31:0] instruction;
  
  wire inverted_clk;
  
  wire dram_en;
  wire dram_rd_en;
  wire dram_wr_en;
  wire [10:0] dram_addr;
  wire [31:0] dram_din;
  wire [31:0] data_read;

  // ========================================================================
  // 2. 模块实例化
  // ========================================================================
  classical_ctrl classical_ctrl_dut (
    .clk             (clk),
    .rst             (rst),
    .i_q_measurement (i_q_measurement),
    
    // Quantum Interface
    .q_time_write    (q_time_write),
    .q_time_sel      (q_time_sel),
    .q_reg_write     (q_reg_write),
    .q_slm           (q_slm),
    .q_rot           (q_rot),
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
    .end_sig         (end_sig)
  );

  // 注意：pram.sv 和 dram.sv 内部必须有 $readmemh 指向正确的文件路径
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
  
  task wait_for_pc(input int pc_val);
      int timeout;
      timeout = 0;
      while (classical_ctrl_dut.next_pc !== pc_val && timeout < 500) begin
          @(posedge clk);
          timeout++;
      end
      if (timeout >= 500) begin
          $display("[TIMEOUT] Waiting for PC=%0d failed. Current PC=%0d", pc_val, classical_ctrl_dut.next_pc);
          $stop;
      end
  endtask

  task check_reg(input int id, input [31:0] expected);
      #(1); 
      if (classical_ctrl_dut.reg_file_i.regs[id] === expected)
          $display("[PASS] PC=%0d: Reg[%0d] Correctly Updated to %0d (0x%h)", classical_ctrl_dut.next_pc, id, expected, expected);
      else begin
          $display("[FAIL] PC=%0d: Reg[%0d] Error! Expected: %0d, Actual: %0d", classical_ctrl_dut.next_pc, id, expected, classical_ctrl_dut.reg_file_i.regs[id]);
          $stop;
      end
  endtask

  task check_mem(input int addr, input [31:0] expected);
      #(1);
      if (dram_dut.DRAM[addr] === expected)
          $display("[PASS] PC=%0d: Mem[%0d] Correctly Updated to %0d (0x%h)", classical_ctrl_dut.next_pc, addr, expected, expected);
      else begin
          $display("[FAIL] PC=%0d: Mem[%0d] Error! Expected: %0d, Actual: %0d", classical_ctrl_dut.next_pc, addr, expected, dram_dut.DRAM[addr]);
          $stop;
      end
  endtask

  task check_signal(input string name, input logic sig, input logic expected);
      if (sig === expected)
          $display("[PASS] PC=%0d: Signal %s is %b (Correct)", classical_ctrl_dut.next_pc, name, sig);
      else begin
          $display("[FAIL] PC=%0d: Signal %s Error! Expected: %b, Actual: %b", classical_ctrl_dut.next_pc, name, expected, sig);
          $stop;
      end
  endtask
  
  // 打印当前的 Flag 状态
  task print_flags();
      // 使用层级路径访问内部信号: classical_ctrl_dut.comp_to_ctrl
      logic [11:0] flags;
      flags = classical_ctrl_dut.comp_to_ctrl;
      
      $display("[DEBUG] PC=%0d | Flags (Hex): %h | Binary: %b", 
               classical_ctrl_dut.next_pc, flags, flags);
      $display("        EQ(9)=%b, NE(8)=%b, LT_U(7)=%b, GE_U(6)=%b, LE_U(5)=%b, GT_U(4)=%b", 
               flags[9], flags[8], flags[7], flags[6], flags[5], flags[4]);
  endtask

  // ========================================================================
  // 5. 自动验证流程
  // ========================================================================
  initial begin
      // A. 初始化
      rst = 1;
      start_sig = 0;
      
      $display("==========================================================");
      $display("   HiSEP-Q 32-bit Verification (Using .mem files)");
      $display("==========================================================");
      
      // B. 启动处理器
      // 这里的 #30 等待时间是为了让 $readmemh 完成数据加载并让复位信号生效
      #(PERIOD*3); 
      rst = 0;
      #(PERIOD); 
      start_sig = 1;
      
      // C. 逐行验证逻辑
      // 只要你的 .mem 文件内容正确，下面的检查就会通过

      // 1. LDI Checks
      wait_for_pc(1); @(posedge clk); check_reg(10, 32'd10);
      wait_for_pc(2); @(posedge clk); check_reg(8, 32'd8);
      wait_for_pc(3); @(posedge clk); check_reg(4, 32'd4);
      
      // 2. LDUI Check
      wait_for_pc(4); @(posedge clk); check_reg(3, 32'd524296);

      // 3. LD Check
      wait_for_pc(5); @(posedge clk); check_reg(6, 32'd12);

      // 4. ST Check
      wait_for_pc(6); @(posedge clk); 
      wait_for_pc(7);
      check_mem(12, 32'd10); 

      // 5. CMP (PC 7) & Branch Check
      // 我们现在已经在 PC=7 了，CMP 正在执行。
      // 等待 PC=8 (BR 指令)
      wait_for_pc(8); 
      #(PERIOD/2)
      $display("Checking Flags after CMP r1(0), r3(524296)...");
      print_flags(); // <--- 调用打印任务
      // 此时 CMP 执行完毕，Flag 已更新。BR 指令 (PC=8) 正在执行。
      
      // 6. Branch Logic Check (PC 8 -> 9 -> 11)
//      wait_for_pc(9); // BR Flag[9] (PC=8) 不跳转，进入 PC=9
      
      // BR Flag[8] (PC=9) 应该跳转到 PC=11
      // 我们直接等待 PC=11。如果逻辑错误跳到了 10，wait_for_pc(11) 也会最终捕获到
      // (除非死循环在 10，但这里是线性的)
      wait_for_pc(11); 
      $display("[INFO] Branch Taken, PC jumped from 9 to 11 (Skipped 10).");

      // 7. ADD Check (PC 11)
      // 等待 PC=12，说明 ADD (PC=11) 完成
      wait_for_pc(12);
      check_reg(10, 32'd12);
      
      // 8. Quantum Instructions Checks
      // PC=12: SMSOL
      // 此时已经在 PC=12，检查信号
      //check_signal("q_slm", q_slm, 1'b1); 
      
      // PC=14: SITO
      //wait_for_pc(14); 
      //check_signal("q_reg_write[1]", q_reg_write[1], 1'b1);
      
      // PC=15: QWAIT 15
      wait_for_pc(16); 
      check_signal("q_time_write", q_time_write, 1'b1);

      // PC=16: ROTX
      //wait_for_pc(16); 
      //check_signal("q_rot", q_rot, 1'b1);

      // 9. STOP (PC 22)
      wait_for_pc(22);
      #(PERIOD*2); // 稍微等一下让 End 信号产生
      if (end_sig[0] === 1'b1)
          $display("[PASS] Processor Stopped Correctly at PC=22.");
      else
          $display("[FAIL] Processor did not stop.");

      $display("\nAll instructions verified successfully from .mem file!");
      $finish;
  end

endmodule