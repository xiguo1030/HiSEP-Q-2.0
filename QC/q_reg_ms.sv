module q_reg_ms (
    input  logic        clk,
    input  logic        reset,
    input  logic [4:0]  wr_addr,
    input  logic [4:0]  rd_addr,
    input  logic        wr_data,
    input  logic        wr_en,
    input  logic        wr_valid,
    output logic [63:0] measure_data
);

    logic [31:0] regs;
    logic [4:0]  reg_wr_addr;

    typedef enum logic [1:0] {
        IDLE        = 2'b00,
        WRITE_WAIT  = 2'b01,
        WRITE_START = 2'b10
    } state_t;

    state_t state, next_state;

    initial regs = 32'hFFFFFFFF;

    // Next State Logic
    always_comb begin
        case (state)
            IDLE:        next_state = wr_en ? WRITE_WAIT : IDLE;
            WRITE_WAIT:  next_state = wr_valid ? WRITE_START : WRITE_WAIT;
            WRITE_START: next_state = IDLE;
            default:     next_state = IDLE;
        endcase
    end

    // State Register
    always_ff @(posedge clk) begin
        if (reset) state <= IDLE;
        else       state <= next_state;
    end

    assign measure_data = {63'b0, regs[rd_addr]}; // Assuming bit extraction to 64-bit?

    // Data Path
    always_ff @(posedge clk) begin
        case (next_state)
            WRITE_WAIT: begin
                if (wr_en) reg_wr_addr <= wr_addr;
            end
            WRITE_START: begin
                regs[reg_wr_addr] <= wr_data;
            end
            default: begin
                // reg_wr_addr <= 5'h1F; // Optional reset
            end
        endcase
    end

endmodule
