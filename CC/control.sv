`include "../parameter.v"

module control (
    input  logic       reset,
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,      
    input  logic       q_inst_sign, 
    input  logic [11:0]comp_flag,
    input  logic [4:0] comp_addr,   

    output logic [3:0] ALU_op,
    output logic       reg_write,
    output logic       mem_write,
    output logic       branch,
    output logic       q_time_write,
    output logic       q_time_sel,
    output logic       q_slm,
    output logic       q_rot,
    output logic [1:0] q_reg_write,
    output logic [2:0] reg_sel,
    output logic [2:0] imm_sel,
    output logic       o_time_reg_en,
    output logic       sel_mux_b
);
    // ... (Parameters 保持不变) ...
    // Classical
    localparam OP_BR       = 7'b0000001;
    localparam OP_JUMP     = 7'b0000010;
    localparam OP_STOP     = 7'b0001000;
    localparam OP_LD       = 7'b0001001;
    localparam OP_ST       = 7'b0001010;
    localparam OP_CMP      = 7'b0001101;
    localparam OP_FBR      = 7'b0010100;
    localparam OP_FMR      = 7'b0010101;
    localparam OP_LDI      = 7'b0101100;
    localparam OP_LDUI     = 7'b0010111;
    
    // ALU Ops
    localparam OP_OR       = 7'b0011000;
    localparam OP_XOR      = 7'b0011001;
    localparam OP_AND      = 7'b0011010;
    localparam OP_NOT      = 7'b0011011;
    localparam OP_ADD      = 7'b0011110;
    localparam OP_SUB      = 7'b0011111;

    // Quantum
    localparam OP_QWAIT    = 7'b1000000;
    localparam OP_QWAITR   = 7'b1000010;
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
        branch = `PC_8; 
        if (opcode == OP_BR) begin
            // 修复 comp_addr 警告：只取有效位防止越界，或者保持原样忽略警告
            if (comp_flag[comp_addr] == 1'b1) 
                branch = `PC_JUMP;
        end else if (opcode == OP_JUMP) begin
            branch = `PC_JUMP;
        end
    end

    // 2. Register Write Enable
    always_comb begin
        reg_write = `REGWE_READ;
        case (opcode)
            OP_LD, OP_LDI, OP_LDUI,
            OP_AND, OP_OR, OP_XOR, OP_NOT, 
            OP_ADD, OP_SUB, 
            OP_FBR, OP_FMR: begin
                reg_write = `REGWE_WRITE;
            end
            default: reg_write = `REGWE_READ; // 显式 Default
        endcase
    end

    // 3. Memory & Imm Logic
    always_comb begin
        mem_write = (opcode == OP_ST && !reset) ? `MEM_WRITE : ~`MEM_WRITE;

        case (opcode)
            OP_LD:     begin imm_sel = `IMM_I;   sel_mux_b = 1'b1; end
            OP_ST:     begin imm_sel = `IMM_S;   sel_mux_b = 1'b1; end
            OP_BR:     begin imm_sel = `IMM_BR;  sel_mux_b = 1'b1; end
            OP_JUMP:   begin imm_sel = `IMM_J;   sel_mux_b = 1'b1; end
            OP_LDI:    begin imm_sel = `IMM_LDI; sel_mux_b = 1'b0; end
            OP_LDUI:   begin imm_sel = `IMM_LDUI;sel_mux_b = 1'b0; end
            OP_QWAIT:  begin imm_sel = `IMM_QW;  sel_mux_b = 1'b0; end
            default:   begin imm_sel = `IMM_NOP; sel_mux_b = 1'b0; end
        endcase
        
        if (opcode == OP_LDI || opcode == OP_LDUI) sel_mux_b = 1'b1;
    end

    // 4. ALU Op
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

    // 5. Reg Sel
    always_comb begin
        if (type_mem)        reg_sel = `REGSRC_MEM;
        else if (type_comp)  reg_sel = `REGSRC_COMP;
        else if (type_measure) reg_sel = `REGSRC_MEA;
        else if (opcode == OP_LDI || opcode == OP_LDUI) reg_sel = `REGSRC_IMM;
        else                 reg_sel = `REGSRC_ALU;
    end

    // 6. Quantum Control Signals (修复 Case 警告)
    always_comb begin
        q_time_write = 0;
        q_time_sel   = 0;
        o_time_reg_en = 0;
        q_reg_write  = 2'b00;
        q_slm        = 0;
        q_rot        = 0;

        if (opcode == OP_QWAIT) begin
            q_time_write = 1;
            q_time_sel   = `TIME_IMM;
        end else if (opcode == OP_QWAITR) begin
            q_time_write = 1;
            q_time_sel   = `TIME_REG;
            o_time_reg_en = 1;
        end

        case (opcode)
            OP_SMSO:  begin q_reg_write = 2'b01; q_slm = 1; end
            OP_SMSOL: begin q_reg_write = 2'b01; end
            OP_SITO:  begin q_reg_write = 2'b10; end
            OP_SITOL: begin q_reg_write = 2'b10; end 
            OP_ROT_X, OP_ROT_Y, OP_ROT_Z: begin q_reg_write = 2'b01; q_rot = 1; end
            default:  begin end // 必须加这个来消除 "not fully specified"
        endcase
    end

endmodule