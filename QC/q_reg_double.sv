module q_reg_double (
    input  logic        clk,
    input  logic        reset,
    input  logic [4:0]  wr_addr,
    input  logic        long_ind,
    input  logic [4:0]  rd_addr1,
    input  logic [4:0]  rd_addr2,
    input  logic [13:0] wr_data_s,
    input  logic [63:0] wr_data_l,
    input  logic [1:0]  wr_en, 
    output logic [13:0] sd_data1_s,
    output logic [13:0] sd_data2_s,
    output logic [104:0]sd_data1_l,
    output logic [104:0]sd_data2_l
);

    logic [13:0]  reg_s [0:15];
    logic [104:0] reg_l [16:31];
    logic [4:0]   reg_wr_addr;

    typedef enum logic [1:0] {
        INITIAL = 2'b01,
        S1      = 2'b10
    } state_t;

    state_t state, next_state;

    // FSM Next State
    always_comb begin
        case (state)
            INITIAL: next_state = (long_ind && wr_en[1]) ? S1 : INITIAL;
            S1:      next_state = INITIAL;
            default: next_state = INITIAL;
        endcase
    end

    // FSM Register
    always_ff @(posedge clk) begin
        if (reset) state <= INITIAL;
        else       state <= next_state;
    end

    // Write Logic (带复位初始化)
    always_ff @(posedge clk) begin
        if (reset) begin
            // 【修复】显式清零，消除 XXX
            for (int i=0; i<16; i++) reg_s[i] <= '0;
            for (int i=16; i<32; i++) reg_l[i] <= '0;
        end else begin
            case (state)
                INITIAL: begin
                    if (wr_en[1]) begin
                        if (long_ind) reg_l[wr_addr][104:64] <= wr_data_l[40:0];
                        else          reg_s[wr_addr]         <= wr_data_s;
                    end
                end
                S1: begin
                    reg_l[reg_wr_addr][63:0] <= wr_data_l;
                end
            endcase
        end
    end

    // Addr Latch
    always_ff @(posedge clk) begin
        case (state)
            INITIAL: reg_wr_addr <= wr_addr;
            S1:      reg_wr_addr <= reg_wr_addr;
            default: reg_wr_addr <= '0;
        endcase
    end

    assign sd_data1_s = (rd_addr1[4]) ? '0 : reg_s[rd_addr1];
    assign sd_data2_s = (rd_addr2[4]) ? '0 : reg_s[rd_addr2];
    assign sd_data1_l = (rd_addr1[4]) ? reg_l[rd_addr1] : '0;
    assign sd_data2_l = (rd_addr2[4]) ? reg_l[rd_addr2] : '0;

endmodule