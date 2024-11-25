// Computes a - b by using two's complement and great_adder
module great_subtractor  #(
    parameter REGISTER_SIZE = 32,
    parameter BITS_IN_NUM = 2048
    )
    (
        input wire [REGISTER_SIZE-1:0] a_in,
        input wire [REGISTER_SIZE-1:0] b_in,
        // input wire carry_in,
        input wire valid_in,
        input wire rst_in,
        input wire clk_in,
        output logic [REGISTER_SIZE-1:0] data_out,
        // output logic sign_out,
        output logic valid_out,
        output logic final_out
    );
    // NOTE: Assumes that A >= B
    // In future can easily update to allow general subtraction 


    logic [31:0] b_complementary;
    assign b_complementary = ~b_in;

    // logic sign;

    great_adder #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(BITS_IN_NUM)  
    )
    add_complement
    (
    .a_in(a_in),
    .b_in(b_complementary),
    .carry_in(1'b1), // want ~B + 1
    
    .valid_in(valid_in),

    .rst_in(rst_in),
    .clk_in(clk_in),

    .data_out(data_out),
    // .carry_out(sign),
    .valid_out(valid_out),
    .final_out(final_out)

);

// assign sign_out = ~sign;


endmodule