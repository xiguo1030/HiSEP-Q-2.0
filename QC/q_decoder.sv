//quantum decoder
//decode the quantum instruction into time infomation/operation/target registers
/*INPUT
QWAIT Imm                       Specify a timing point by waiting for the number of cycles indicated
 
|---|----------|----------|----------|----------|----------|
|31 | 30 .. 25 | 24 .. 20 | 19 .. 15 | 14 .. 10 | 9 ..   0 |
|---|--opcode--|----------|----------|----------|----------|
|---|----------|----------|----------|----------|----------|
| 0 |  100000  | reserved |     imm20                      |
|---|----------|----------|----------|----------|----------|
 
QWAITR Rs                       by the immediate value Imm or the value of GPR Rs.
 
|---|----------|----------|----------|----------|----------|
|31 | 30 .. 25 | 24 .. 20 | 19 .. 15 | 14 .. 10 | 9 ..   0 |
|---|--opcode--|----------|----------|----------|----------|
|---|----------|----------|----------|----------|----------|
| 0 |  100001  | reserved |     Rs   |      imm15          |
|---|----------|----------|----------|----------|----------|
 
SMSO Sd, <Qubit List>   
|---|----------|----------|----------|----------|----------|
|31 | 30 .. 25 | 24 .. 20 | 19 .. 15 | 14 ..  8 | 7 ..   0 |
|---|--opcode--|----------|----------|----------|----------|
|---|----------|----------|----------|----------|----------|
| 0 |  101000  |   Sd     |    reserved         |   imm8   |
|---|----------|----------|----------|----------|----------|

SMSOL Sd, <Qubit List>     pcode the same 改为 101011            + 32*3 = 96 bit mask
|---|----------|----------|----------|----------|----------|
|31 | 30 .. 25 | 24 .. 20 | 19 .. 15 | 14 ..  5 | 4 ..   0 |
|---|--opcode--|----------|----------|----------|----------|
|---|----------|----------|----------|----------|----------|
| 0 |  111000  |   Sd     |    reserved         |   imm4   |
|---|----------|----------|----------|----------|----------|
 

SSMSO Sd, <Qubit List>     pcode the same 改为 101011  set sliding-mask for single qubit operation_short 8*2^4 = 8*16 = 128
|---|----------|----------|----------|----------|----------|
|31 | 30 .. 25 | 24 .. 20 | 19 .. 12 | 11 ..  8 | 7 ..   0 |
|---|--opcode--|----------|----------|----------|----------|
|---|----------|----------|----------|----------|----------|
| 0 |  101001  |   Sd     | reserved |  Offset  |   imm8   |
|---|----------|----------|----------|----------|----------|


SITO Td, <Qubit Pair index>      Update the two qubit operation target register Sd (Td). set immeidate for two-qubit operation
 
|---|----------|----------|----------|----------|----------|
|31 | 30 .. 25 | 24 .. 20 | 19 .. 14 | 13 .. 7  | 6 ..    0|
|---|--opcode--|----------|----------|----------|----------|
|---|----------|----------|----------|----------|----------|
| 0 |  101100  |   Td     |  reserve |   imm7   |    imm7  |
|---|----------|----------|----------|----------|----------|


SITOL Sd, <Qubit List indexex>     pcode the same 改为 101011            + 14*7 = 98 bit
|---|----------|----------|----------|----------|----------|
|31 | 30 .. 25 | 24 .. 20 | 19 .. 9 | 8 ..  2  | 1 ..   0 |
|---|--opcode--|----------|----------|----------|----------|
|---|----------|----------|----------|----------|----------|
| 0 |  111100  |   Td     | reserved | mask(0 unused,1 used) |   imm2(two MSB of the first immediate numebr)   |
|---|----------|----------|----------|----------|----------|
 
[PI,] Q_Op [| Q_Op]*            Applying operations on qubits after waiting for a small number of cycles indicated by PI.
quantum opration depends on gate sets, currently predefined ** gate sets, gate operation can be ranged uptp 2^9
|---|--------------------|----------|----------|----------|----------|
|31 |         30 .. 22   | 21 .. 17 | 16 .. 8  | 7 .. 3   | 2 .. 0   |
|---|--q_opcode--------- |----------|----------|----------|----------|
|---|----------------- --|----------|----------|----------|----------|
| 1 |  quantum opration  |   Si/Ti_0|q_opration| Si/Ti_1  |   PI     |
|---|--------------------|----------|----------|---------------------|


also 32'b0, when input is not quantum, important to handle this problem
*/
`include "../parameter.v"

module q_decoder(
    input  logic [63:0] q_instruction,
    input  logic [63:0] i_register, 
    input  logic        q_time_sel,
    input  logic [19:0] t_cnt,
    output logic [19:0] timing,
    output logic [2:0]  pi,
    output logic [4:0]  Si_addr,
    output logic [4:0]  Ti_addr,
    output logic [45:0] Si_reg_s,
    output logic [13:0] Ti_reg_s,
    output logic [63:0] Q_reg_l, 
    output logic [4:0]  Si_offset,
    output logic [10:0] angle,
    output logic [4:0]  q_reg_rd_addr1,
    output logic [4:0]  q_reg_rd_addr2,
    output logic [6:0]  q_opcode1,
    output logic [6:0]  q_opcode2
);

    logic [19:0] time_imm, time_reg, time_temp;

    assign time_imm = q_instruction[19:0];
    assign time_reg = i_register[19:0];

    always_comb begin
        case (q_time_sel)
            `TIME_REG: time_temp = time_reg;
            `TIME_IMM: time_temp = time_imm;
            default:   time_temp = time_imm;
        endcase
    end

    always_comb begin
        Si_reg_s       = q_instruction[45:0];
        Si_addr        = q_instruction[55:51];
        Ti_addr        = q_instruction[55:51];
        Ti_reg_s       = q_instruction[13:0];
        Q_reg_l        = q_instruction;
        Si_offset      = q_instruction[50:46];
        q_reg_rd_addr1 = q_instruction[55:51];
        q_reg_rd_addr2 = q_instruction[43:39];
        angle          = q_instruction[10:0];
    end

    always_comb begin
        if (q_instruction[63]) begin // Quantum operation instruction
            q_opcode1 = q_instruction[62:56];
            q_opcode2 = q_instruction[50:44];
            pi        = q_instruction[2:0];
        end else begin
            q_opcode1 = '0;
            q_opcode2 = '0;
            pi        = '0;
        end
    end

    assign timing = time_temp + t_cnt;

endmodule
