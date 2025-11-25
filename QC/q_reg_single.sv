//discription:
/*
Storing all the nessasary register file for single qubit operation;

1. 46-bit single qubit register (was 8 before) - 15 pieces (0-15)
2. 5-bit sliding mask (15 pieces, bounded with short)
3. 11-bit angles for arbitrary angle operation (32 pieces)
4. 110-bit long qubit register - 15 pieces (16-32), controlled by a 2-state FSM




*/


module q_reg_single (
    input  logic        clk,
    input  logic        reset,
    input  logic [4:0]  wr_addr,
    input  logic        q_slm,
    input  logic        long_ind, 
    input  logic [4:0]  rd_addr1,
    input  logic [4:0]  rd_addr2,
    input  logic [4:0]  Si_offset,
    input  logic [45:0] wr_data_s,
    input  logic [63:0] wr_data_l,
    input  logic [1:0]  wr_en, 
    input  logic [10:0] angle,
    input  logic        q_rot,
    
    output logic [4:0]  sd_offset1,
    output logic [4:0]  sd_offset2,
    output logic [45:0] sd_data1_s,
    output logic [45:0] sd_data2_s,
    output logic [109:0]sd_data1_l,
    output logic [109:0]sd_data2_l,
    output logic [10:0] sd_angle1,
    output logic [10:0] sd_angle2
);

    // Memories
    logic [45:0]  reg_s [0:15];
    logic [4:0]   reg_offset [0:15];
    logic [10:0]  reg_angle [0:31];
    logic [109:0] reg_l [16:31];
    
    logic [4:0]   reg_wr_addr;

    // FSM using Enum
    typedef enum logic [1:0] {
        INITIAL = 2'b01,
        S1      = 2'b10
    } state_t;

    state_t state, next_state;

    // --- Offset & Angle Write Logic ---
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i=0; i<16; i++) reg_offset[i] <= '0;
            for (int i=0; i<32; i++) reg_angle[i] <= '0;
        end else if (wr_en[0] && !long_ind) begin
            reg_offset[wr_addr] <= q_slm ? Si_offset : 5'b0;
            reg_angle[wr_addr]  <= q_rot ? {angle[10], angle[10], angle[10:2]} : 11'b0; 
        end
    end

    // --- FSM Next State ---
    always_comb begin
        case (state)
            INITIAL: next_state = (long_ind && wr_en[0]) ? S1 : INITIAL;
            S1:      next_state = INITIAL;
            default: next_state = INITIAL;
        endcase
    end

    // --- FSM State Update ---
    always_ff @(posedge clk) begin
        if (reset) state <= INITIAL;
        else       state <= next_state;
    end

    // --- Main Register Write Logic ---
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i=0; i<16; i++) reg_s[i] <= '0;
            for (int i=16; i<32; i++) reg_l[i] <= '0;
        end else begin
            case (state)
                INITIAL: begin
                    if (wr_en[0]) begin
                        if (long_ind) reg_l[wr_addr][109:64] <= wr_data_l[45:0];
                        else          reg_s[wr_addr]         <= wr_data_s;
                    end
                end
                S1: begin
                    reg_l[reg_wr_addr][63:0] <= wr_data_l;
                end
            endcase
        end
    end

    // --- Address Latch Logic ---
    always_ff @(posedge clk) begin
        case (state)
            INITIAL: reg_wr_addr <= wr_addr;
            S1:      reg_wr_addr <= reg_wr_addr; // Hold
            default: reg_wr_addr <= '0;
        endcase
    end

    // --- Output Logic ---
    assign sd_data1_s = (rd_addr1[4]) ? '0 : reg_s[rd_addr1];
    assign sd_data2_s = (rd_addr2[4]) ? '0 : reg_s[rd_addr2];
    assign sd_offset1 = (rd_addr1[4]) ? '0 : reg_offset[rd_addr1];
    assign sd_offset2 = (rd_addr2[4]) ? '0 : reg_offset[rd_addr2];
    assign sd_angle1  = reg_angle[rd_addr1];
    assign sd_angle2  = reg_angle[rd_addr2];
    assign sd_data1_l = (rd_addr1[4]) ? reg_l[rd_addr1] : '0;
    assign sd_data2_l = (rd_addr2[4]) ? reg_l[rd_addr2] : '0;

endmodule
