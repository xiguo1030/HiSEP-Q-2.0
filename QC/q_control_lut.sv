`include "../parameter.v"

module q_control_lut (
    input  logic [6:0] q_opcode,
    input  logic       q_op_sign, 
    output logic [4:0] q_micro_op,
    output logic       meas_write_en,
    output logic       timestamp_rd_en,
    output logic [1:0] q_op_sel
);

    always_comb begin
        q_op_sel        = 2'b00;
        q_micro_op      = `QNOP;
        timestamp_rd_en = 1'b0;

        if (q_op_sign) begin
            timestamp_rd_en = 1'b1;
            case (q_opcode)
                7'd0: begin q_micro_op = `QNOP;   q_op_sel[0] = 0; end
                7'd1: begin q_micro_op = `X180;   q_op_sel[0] = 1; end
                7'd2: begin q_micro_op = `X90;    q_op_sel[0] = 1; end
                7'd3: begin q_micro_op = `X90R;   q_op_sel[0] = 1; end
                7'd4: begin q_micro_op = `Y180;   q_op_sel[0] = 1; end
                7'd5: begin q_micro_op = `Y90;    q_op_sel[0] = 1; end
                7'd6: begin q_micro_op = `Y90R;   q_op_sel[0] = 1; end
                7'd7: begin q_micro_op = `MEAS;   q_op_sel[0] = 1; end
                7'd8: begin q_micro_op = `Z;      q_op_sel[0] = 1; end
                7'd9: begin q_micro_op = `T;      q_op_sel[0] = 1; end
                7'd10:begin q_micro_op = `T_adj;  q_op_sel[0] = 1; end
                7'd11:begin q_micro_op = `S;      q_op_sel[0] = 1; end
                7'd12:begin q_micro_op = `S_adj;  q_op_sel[0] = 1; end
                7'd13:begin q_micro_op = `RZ;     q_op_sel[0] = 1; end
                7'd14:begin q_micro_op = `RESET;  q_op_sel[0] = 1; end
                7'd15:begin q_micro_op = `HAMD;   q_op_sel[0] = 1; end
                
                7'd16:begin q_micro_op = `CNOT;   q_op_sel[1] = 1; end
                7'd17:begin q_micro_op = `CZ;     q_op_sel[1] = 1; end
                7'd18:begin q_micro_op = `SWAP;   q_op_sel[1] = 1; end
                
                7'b1010011:begin q_micro_op = `R_X; q_op_sel[0] = 1; end
                7'b1010100:begin q_micro_op = `R_Y; q_op_sel[0] = 1; end
                7'b1010101:begin q_micro_op = `R_Z; q_op_sel[0] = 1; end
                
                default: begin q_micro_op = `QNOP; q_op_sel = 2'b00; end
            endcase
        end
    end

    always_comb begin
        if (q_opcode == 7'd7) meas_write_en = 1'b1;
        else                  meas_write_en = 1'b0;
    end

endmodule
