`include "../parameter.v"

module control (
    input  logic       reset,
    input  logic [6:0] opcode,
    input  logic       q_inst_sign,
    input  logic [11:0]comp_flag,
    input  logic [3:0] comp_addr,

    output logic [3:0] ALU_op,
    output logic       reg_write,
    output logic       mem_write,
    output logic       branch,
    output logic       q_time_write,
    output logic       q_time_sel,
    output logic       q_vliw,
    output logic       q_slm,
    output logic       q_rot,
    output logic [1:0] q_reg_write,
    output logic [2:0] reg_sel,
    output logic [2:0] imm_sel,
    output logic       o_time_reg_en,
    output logic       sel_mux_b
);

    // --- ISA OPCODE DEFINITIONS ---
    // Classical
    localparam OP_CMP      = 7'b0001101;
    localparam OP_BR       = 7'b0000001;
    localparam OP_JUMP     = 7'b0000010;
    localparam OP_LD       = 7'b0001001;
    localparam OP_ST       = 7'b0001010;
    localparam OP_LDI      = 7'b0010110;
    localparam OP_LDUI     = 7'b0010111;
    localparam OP_AND      = 7'b0011010;
    localparam OP_OR       = 7'b0011000;
    localparam OP_XOR      = 7'b0011001;
    localparam OP_NOT      = 7'b0011011;
    localparam OP_ADD      = 7'b0011110;
    localparam OP_SUB      = 7'b0011111;
    localparam OP_FBR      = 7'b0010100;
    localparam OP_FMR      = 7'b0010101;
    
    // Quantum
    localparam OP_QWAIT    = 7'b1000000;
    localparam OP_QWAITR   = 7'b1000001;
    localparam OP_SMSO     = 7'b1001000;
    localparam OP_SMSOL    = 7'b1001010;
    localparam OP_SITO     = 7'b1001100;
    localparam OP_SITOL    = 7'b1001011;
    localparam OP_ROT_X    = 7'b1010011;
    localparam OP_ROT_Y    = 7'b1010100;
    localparam OP_ROT_Z    = 7'b1010101;

    // --- DECODER LOGIC ---
    logic type_mem, type_comp, type_measure;

    assign type_comp    = (opcode == OP_FBR);
    assign type_measure = (opcode == OP_FMR);
    assign type_mem     = (opcode == OP_LD); 

    // 1. Branch Logic
    always_comb begin
        if (opcode == OP_BR) begin
            if (comp_flag[comp_addr] == 1'b1)
                branch = `PC_JUMP;
            else
                branch = `PC_8;
        end else if (opcode == OP_JUMP) begin
            branch = `PC_JUMP;
        end else begin
            branch = `PC_8;
        end
    end

    // 2. Register Write Enable (【关键修复】改为白名单模式)
    always_comb begin
        if (reset) begin
            reg_write = `REGWE_READ;
        end else begin
            // 默认关闭写使能 (这能防止 Payload/NOP/Opcode 0 误写寄存器)
            reg_write = `REGWE_READ;

            // 白名单：只有明确需要写寄存器的指令才打开
            case (opcode)
                OP_LD, 
                OP_LDI, 
                OP_LDUI,
                OP_AND, OP_OR, OP_XOR, OP_NOT, 
                OP_ADD, OP_SUB, 
                OP_FBR, OP_FMR: begin
                    reg_write = `REGWE_WRITE;
                end
                // 注意：
                // - OP_CMP 只更新 flag，不写寄存器，所以不在白名单
                // - OP_ST, BR, JUMP 不写寄存器
                // - Quantum 指令不写经典寄存器
                // - Opcode 0 (Payload) 不在 case 里，默认走 REGWE_READ，安全！
            endcase
        end
    end

    // 3. Memory & Imm Logic
    always_comb begin
        mem_write = (opcode == OP_ST && !reset) ? `MEM_WRITE : ~`MEM_WRITE;

        // Immediate Selection
        case (opcode)
            OP_LD, OP_ST: begin
                imm_sel = `IMM_M;
                sel_mux_b = 1'b1;
            end
            OP_BR, OP_JUMP: begin
                imm_sel = `IMM_BR;
                sel_mux_b = 1'b1;
            end
            OP_LDI: begin
                imm_sel = `IMM_LDI;
                sel_mux_b = 1'b0; 
            end
            OP_LDUI: begin
                imm_sel = `IMM_LDUI;
                sel_mux_b = 1'b0;
            end
            default: begin
                imm_sel = `IMM_NOP;
                sel_mux_b = 1'b0; 
            end
        endcase
        
        if (opcode == OP_LDI || opcode == OP_LDUI) sel_mux_b = 1'b1; 
    end

    // 4. ALU Operation Selection
    always_comb begin
        case (opcode)
            OP_AND: ALU_op = `AND;
            OP_OR:  ALU_op = `OR;
            OP_XOR: ALU_op = `XOR;
            OP_NOT: ALU_op = `NOT;
            OP_ADD, OP_LD, OP_ST: ALU_op = `ADD; 
            OP_SUB: ALU_op = `SUB;
            OP_CMP: ALU_op = `CMP;
            default: ALU_op = `ADD;
        endcase
    end

    // 5. Register Write Source
    always_comb begin
        if (type_mem)        reg_sel = `REGSRC_MEM;
        else if (type_comp)  reg_sel = `REGSRC_COMP;
        else if (type_measure) reg_sel = `REGSRC_MEA;
        else if (opcode == OP_LDI || opcode == OP_LDUI) reg_sel = `REGSRC_IMM; 
        else                 reg_sel = `REGSRC_ALU;
    end

    // 6. Quantum Control Signals
    always_comb begin
        q_time_write = 0;
        q_time_sel   = 0;
        o_time_reg_en = 0;
        q_reg_write  = 2'b00;
        q_slm        = 0;
        q_vliw       = 0;
        q_rot        = 0;

        if (opcode == OP_QWAIT) begin
            q_time_write = 1;
            q_time_sel   = `TIME_IMM;
        end else if (opcode == OP_QWAITR) begin
            q_time_write = 1;
            q_time_sel   = `TIME_REG;
            o_time_reg_en = 1;
        end

        if (!q_inst_sign) begin
            case (opcode)
                OP_SMSO:  begin q_reg_write = 2'b01; q_slm = 1; end
                OP_SMSOL: begin q_reg_write = 2'b01; q_vliw = 1; end
                OP_SITO:  begin q_reg_write = 2'b10; end
                OP_SITOL: begin q_reg_write = 2'b10; q_vliw = 1; end
                OP_ROT_X, OP_ROT_Y, OP_ROT_Z: begin q_reg_write = 2'b01; q_rot = 1; end
            endcase
        end
    end

endmodule