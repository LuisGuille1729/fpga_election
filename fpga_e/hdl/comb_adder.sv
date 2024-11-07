`default_nettype none
module comb_adder  #(
    parameter  DATA_BIT_SIZE= 1 )
    (
        input wire[DATA_BIT_SIZE-1:0] a_in,
        input wire[DATA_BIT_SIZE-1:0] b_in,
        input wire carry_in,
        output logic carry_out,
        output logic[DATA_BIT_SIZE-1:0] c_out
    );

    logic [DATA_BIT_SIZE-1:0] temp1;
    logic [DATA_BIT_SIZE-1:0] temp2;
    logic [DATA_BIT_SIZE-1:0] temp3;
    logic temp4;
    logic temp5;
    logic temp6;
    logic [DATA_BIT_SIZE:0] temp7;

    always_comb begin
        if (DATA_BIT_SIZE == 1) begin
            temp7 = a_in + b_in + carry_in;
            c_out = temp7[0];
            carry_out = temp7[1];
        end
        else begin

            comb_adder #(.DATA_BIT_SIZE(DATA_BIT_SIZE/2)) 
            add_low (
                .a_in(a_in[DATA_BIT_SIZE/2 -1: 0]),
                .b_in(b_in[DATA_BIT_SIZE/2 -1: 0]),
                .carry_in(carry_in),
                .c_out(temp1),
                .carry_out(temp4)
            );

            comb_adder #(.DATA_BIT_SIZE(DATA_BIT_SIZE/2)) 
            add_high0 (
                .a_in(a_in[DATA_BIT_SIZE-1: DATA_BIT_SIZE/2]),
                .b_in(b_in[DATA_BIT_SIZE-1: DATA_BIT_SIZE/2]),
                .carry_in(0),
                .c_out(temp2),
                .carry_out(temp5)
            );

            comb_adder #(.DATA_BIT_SIZE(DATA_BIT_SIZE/2)) 
            add_high1 (
                .a_in(a_in[DATA_BIT_SIZE-1: DATA_BIT_SIZE/2]),
                .b_in(b_in[DATA_BIT_SIZE-1: DATA_BIT_SIZE/2]),
                .carry_in(1),
                .c_out(temp3),
                .carry_out(temp6)
            );

        
            assign c_out = (temp4) ? {temp3, temp1} : {temp2, temp1};
            assign carry_out = (temp4) ? temp6 : temp5;



        end
    end

   

endmodule

`default_nettype wire
