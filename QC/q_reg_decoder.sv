module q_reg_decoder(
    input  logic [45:0]  sreg_data_s,
    input  logic [109:0] sreg_data_l,
    input  logic [13:0]  treg_data_s,
    input  logic [104:0] treg_data_l,
    input  logic [4:0]   reg_off,
    input  logic [4:0]   reg_read_addr,
    input  logic [1:0]   q_reg_sel, // 01:single, 10:double
    output logic [219:0] q_op_out
);

    logic [219:0] q_op_single;
    logic [219:0] q_op_double;
    logic [7:0]   treg_mask;
    logic [7:0]   t_data_addr1, t_data_addr2;

    assign treg_mask = treg_data_l[104:98];

    // Single Qubit Ops
    always_comb begin
        q_op_single = '0;
        if (reg_read_addr[4]) begin // Long
            for (int i = 0; i < 110; i++)
                q_op_single[2*i +: 2] = {2{sreg_data_l[i]}};
        end else begin // Short (with Offset)
            for (int k = 0; k < 46; k++)
                q_op_single[(8*reg_off + 2*k) +: 2] = {2{sreg_data_s[k]}};
        end
    end

    // Double Qubit Ops
    always_comb begin
        q_op_double = '0;
        if (reg_read_addr[4]) begin // Long
            for (int j = 0; j < 7; j++) begin
                t_data_addr1 = (treg_data_l[14*j +: 6]) << 1;
                t_data_addr2 = (treg_data_l[14*j+7 +: 6]) << 1;
                
                q_op_double[t_data_addr1 +: 2] = treg_mask[j] ? 2'b10 : 2'b00;
                q_op_double[t_data_addr2 +: 2] = treg_mask[j] ? 2'b01 : 2'b00;
            end
        end else begin // Short
            q_op_double[(treg_data_s[6:0] << 1) +: 2]  = 2'b10;
            q_op_double[(treg_data_s[13:7] << 1) +: 2] = 2'b01;
        end
    end

    assign q_op_out = q_reg_sel[0] ? q_op_single : (q_reg_sel[1] ? q_op_double : '0);

endmodule
