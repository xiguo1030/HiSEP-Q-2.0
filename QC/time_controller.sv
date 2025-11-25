module time_controller(
    input  logic        clk,
    input  logic        reset,
    input  logic [19:0] t_cnt,
    // FIFO Interface
    output logic        fifo_rd_en,
    input  logic [37:0] fifo_data,
    input  logic        fifo_empty,

    // Output Interface
    output logic [17:0] o_data,
    output logic        o_data_wr_en,
    output logic [10:0] o_data_mem_addr
);

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        WAIT  = 2'b01,
        ISSUE = 2'b10
    } state_t;

    state_t state, next_state;

    logic [6:0]  opcode;
    logic [19:0] t_inst;
    logic [10:0] angle;
    logic        wr_en;
    logic [10:0] mem_addr, mem_addr_next;

    // Combinational assignments
    assign angle           = fifo_data[10:0];
    assign opcode          = fifo_data[17:11];
    assign t_inst          = fifo_data[37:18];
    assign o_data_wr_en    = wr_en;
    assign o_data_mem_addr = mem_addr;

    // Next State Logic
    always_comb begin
        case (state)
            IDLE:    next_state = (!fifo_empty) ? WAIT : IDLE;
            WAIT:    next_state = (t_inst == (t_cnt + 20'b1)) ? ISSUE : WAIT;
            ISSUE:   next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State & Memory Address Register
    always_ff @(posedge clk) begin
        if (reset) begin
            state    <= IDLE;
            mem_addr <= '0;
        end else begin
            state    <= next_state;
            mem_addr <= mem_addr_next;
        end
    end

    // Output Logic
    always_comb begin
        fifo_rd_en    = 1'b0;
        o_data        = '0;
        wr_en         = 1'b0;
        mem_addr_next = mem_addr; // Default hold

        case (state)
            IDLE: begin
                fifo_rd_en = 1'b1;
            end
            ISSUE: begin
                o_data        = {opcode, angle};
                wr_en         = 1'b1;
                mem_addr_next = mem_addr + 11'b1;
            end
            default: begin end
        endcase
    end

endmodule
