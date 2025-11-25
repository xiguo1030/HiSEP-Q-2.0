module dispatcher #(parameter integer NCH = 4) (
    input  logic        clk,
    input  logic        reset,
    input  logic [52+NCH*4-1:0] comb,
    output logic [20*NCH-1:0]   abs_time,
    output logic [NCH-1:0]      fifo_wr_en,
    output logic [18*NCH-1:0]   fifo_wd,
    output logic [NCH-1:0]      err_bit
);

    logic [4:0]   opcode_a, opcode_b;
    logic [19:0]  input_time;
    logic [2*NCH-1:0] mask_a, mask_b;
    logic [10:0]  angle_a, angle_b;
    logic         rot_a, rot_b;

    assign input_time = comb[52+NCH*4-1 -: 20];
    assign opcode_a   = comb[52+NCH*4-1-20 -: 5];
    assign mask_a     = comb[52+NCH*4-1-25 -: 2*NCH];
    assign angle_a    = comb[52+NCH*4-1-25-2*NCH -: 11];
    assign opcode_b   = comb[52+NCH*4-1-25-2*NCH-11 -: 5];
    assign mask_b     = comb[52+NCH*4-1-25-2*NCH-11-5 -: 2*NCH];
    assign angle_b    = comb[10:0];

    assign rot_a = (opcode_a >= 19 && opcode_a <= 21);
    assign rot_b = (opcode_b >= 19 && opcode_b <= 21);

    genvar i;
    generate
        for (i=0; i<NCH; i++) begin : channel_gen
            logic sel_a, sel_b;
            logic [4:0]  opcode_vec;
            logic [1:0]  mask_vec_slice;
            logic [10:0] angle_vec;

            assign sel_a = mask_a[2*i] | mask_a[2*i+1];
            assign sel_b = mask_b[2*i] | mask_b[2*i+1];
            
            assign mask_vec_slice[0] = mask_a[2*i]   | mask_b[2*i];
            assign mask_vec_slice[1] = mask_a[2*i+1] | mask_b[2*i+1];

            // Logic optimization for Muxes
            always_comb begin
                if (err_bit[i]) opcode_vec = 5'b0;
                else if (sel_a) opcode_vec = opcode_a;
                else if (sel_b) opcode_vec = opcode_b;
                else            opcode_vec = 5'b0;
            end

            always_comb begin
                if (err_bit[i]) angle_vec = 11'b0;
                else if (rot_a && sel_a) angle_vec = angle_a;
                else if (rot_b && sel_b) angle_vec = angle_b;
                else                     angle_vec = 11'b0;
            end

            // Output Registers
            always_comb begin
                if (reset) begin
                    fifo_wr_en[i]           = 1'b0;
                    abs_time[20*i +: 20]    = '0;
                    err_bit[i]              = 1'b0;
                    fifo_wd[18*i +: 18]     = '0;
                end else begin
                    err_bit[i] = sel_a && sel_b;
                    fifo_wr_en[i] = err_bit[i] ? 1'b0 : (sel_a || sel_b);
                    abs_time[20*i +: 20] = err_bit[i] ? 20'b0 : input_time;
                    fifo_wd[18*i +: 18] = {opcode_vec, mask_vec_slice, angle_vec};
                end
            end
        end
    endgenerate

endmodule
