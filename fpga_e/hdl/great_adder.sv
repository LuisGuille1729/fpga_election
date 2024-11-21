`default_nettype none
// computes addition of 2 numbers by writting to block ram and sending the data back out in cycles
// has a valid out signal and a last signal to showcase a finished addition. 
module great_adder  #(
    parameter REGISTER_SIZE = 32,
    parameter BITS_IN_NUM = 2048
    )
    (
        input wire [register_size-1:0] a_in,
        input wire [register_size-1:0] b_in,
        input wire carry_in,
        input wire valid_in,
        input wire rst_in,
        input wire clk_in,
        output logic [register_size-1:0] data_out,
        output logic carry_out,
        output logic valid_out,
        output logic final_out
    );
    localparam num_packets_in_num = bits_in_num/register_size;
    logic[$clog2(num_packets_in_num):0] curr_count;
    logic carry_used;
    logic cur_carry;
    assign carry_used = curr_count == 0? carry_in: cur_carry;
    logic[register_size:0] sum;
    assign sum  = a_in + b_in + carry_used;

    assign carry_out = sum[register_size];
    assign final_out = curr_count == num_packets_in_num -1;
    assign valid_out = valid_in;
    assign data_out = sum[register_size-1:0];
    always_ff @( posedge clk_in ) begin 
        if (rst_in)begin
            curr_count <=0;
            cur_carry<=0;
        end else begin
            if (valid_in) begin
                cur_carry <= sum[register_size];
                curr_count<=curr_count == num_packets_in_num -1? 0: curr_count +1;
            end
        end
    end






endmodule

`default_nettype wire
