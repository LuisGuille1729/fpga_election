// `default_nettype none
// // computes addition of 2 numbers by writing to block ram and sending the data back out in cycles
// // has a valid out signal and a last signal to showcase a finished addition. 
// module mod_n  #(
//     parameter REGISTER_SIZE = 32,
//     parameter BITS_IN_NUM = 2048
//     )
//     (
//         input wire [REGISTER_SIZE-1:0] num_in,
//         input wire valid_in,
//         input wire rst_in,
//         input wire clk_in,
//         output logic [REGISTER_SIZE-1:0] data_out,
//         output logic valid_out
//     );

//     localparam NUM_BLOCKS_IN = REGISTER_SIZE/BITS_IN_NUM ;

//     fixed_divider #(
//     .REGISTER_SIZE(REGISTER_SIZE),
//     .NUM_BLOCKS_IN(128),
//     //idk what this is
//     // parameter BITS_EXPONENT = 6080, // only change if changing divider n
//     .NUM_BLOCKS_OUT(NUM_BLOCKS_IN/2)
// )(
//     input wire clk_in,
//     input wire rst_in,

//     input wire valid_in,
//     input wire [REGISTER_SIZE-1:0] x_block_in,   // the number we want to divide by
    
//     // input wire [REGISTER_SIZE-1:0] mult_inv_constant_block_in, // we implement in top level so that it is paired at the same time with the corresponding x_block_in. In future, can implement this directly.

//     output logic valid_out,
//     output logic [REGISTER_SIZE-1:0] data_block_out
// );





// endmodule
// `default_nettype wire