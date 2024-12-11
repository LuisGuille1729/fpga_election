// `default_nettype none
// module montgomery_squarer_stream #(
//     parameter REGISTER_SIZE = 32,
//     parameter BITS_IN_NUM = 2048,
//     parameter R = 4096
// ) (
//     input wire clk_in,
//     input wire rst_in,

//     input wire [REGISTER_SIZE-1:0] N_in,
//     input wire [REGISTER_SIZE-1:0] k_in,
    
//     input wire [REGISTER_SIZE-1:0] reduced_modulo_block_in,
//     input wire data_valid_in,

//     output logic consumed_k_out,
//     output logic consumed_N_out,

//     output logic [REGISTER_SIZE-1:0] reduced_square_out,
//     output logic squared_valid_out
// );

//     localparam BITS_IN_OUT = 2 * BITS_IN_NUM;  // 2*BITS_IN_NUM bit output from montgomery passed into multiplier
//     localparam NUM_BLOCKS_IN_OUT = BITS_IN_OUT / REGISTER_SIZE;
//     localparam HIGHEST_EXPONENT = BITS_IN_NUM;
//     localparam BITS_IN_EXPONENT = $clog2(HIGHEST_EXPONENT);

//     logic [$clog2(NUM_BLOCKS_IN_OUT)-1:0] block_ctr;
//     logic [BITS_IN_EXPONENT-1:0] square_exponent_ctr;
//     logic [REGISTER_SIZE-1:0] squared_modulo_block;
//     logic reset_multiplier;
//     logic multiplier_blocked;

//     always_comb begin
//         if (rst_in) begin
//             reduced_square_out = 0;
//             squared_valid_out = 0;
//             reset_multiplier = 1;
//         end
//         else begin
//             reduced_square_out = data_valid_in ? reduced_modulo_block_in : reducer_block_out;
//             squared_valid_out = data_valid_in | reducer_valid_out;
//             reset_multiplier = (block_ctr == NUM_BLOCKS_IN_OUT - 1) && (square_exponent_ctr == HIGHEST_EXPONENT - 1);
//         end
//     end

//     always_ff @(posedge clk_in) begin
//         if (rst_in) begin
//             block_ctr <= 0;
//             square_exponent_ctr <= 0;
//             multiplier_blocked <= 0;
//         end
//         else if (squared_valid_out) begin
//             if (data_vallid_in) begin
//                 // if ((block_ctr == NUM_BLOCKS_IN_OUT - 1 && square_exponent_ctr == HIGHEST_EXPONENT - 1))
//                 multiplier_blocked <= 0;  // Once we get a new input, unblock the multiplier from a previously completed input
//             end
//             if (block_ctr == NUM_BLOCKS_IN_OUT - 1) begin
//                 block_ctr <= 0;
//                 if (square_exponent_ctr == HIGHEST_EXPONENT - 1) begin
//                     multiplier_blocked <= 1;  // Last iteration, so block multiplier - it'll also be reset
//                     square_exponent_ctr <= 0;
//                 end
//                 else if (~data_valid_in) begin
//                     square_exponent_ctr <= square_exponent_ctr + 1;
//                 end
//             end
//             else begin
//                 block_ctr <= block_ctr + 1;
//             end
//         end
//     end

//     logic multiplier_valid_out;
//     logic [REGISTER_SIZE-1:0] multiplier_block_out;
//     fsm_multiplier #(
//         .REGISTER_SIZE(REGISTER_SIZE),
//         .BITS_IN_NUM(BITS_IN_OUT)
//     ) squarer_stream (
//         .n_in(reduced_square_out),
//         .m_in(reduced_square_out),
//         // data_valid_in should always override the multiplier being blocked from a last input (since we're dealing with a new input)
//         .valid_in(squared_valid_out & (~multiplier_blocked | data_valid_in)),
//         .rst_in(reset_multiplier),
//         .clk_in(clk_in),
//         .data_out(multiplier_block_out),
//         .valid_out(multiplier_valid_out),
//         .final_out(),
//         .ready_out()
//     );

//     logic reducer_valid_out;
//     logic [REGISTER_SIZE-1:0] reducer_block_out;
//     montgomery_reduce #(
//         .REGISTER_SIZE(REGISTER_SIZE),
//         .NUM_BLOCKS(2 * NUM_BLOCKS_IN_OUT),
//         .R(R)
//     ) squarer_stream_reducer (
//         .clk_in(clk_in),
//         .rst_in(rst_in),

//         .valid_in(multiplier_valid_out),
//         .T_block_in(multiplier_block_out),

//         .k_constant_block_in(k_in),
//         .consumed_k_out(consumed_k_out),

//         .modN_constant_block_in(N_in),
//         .consumed_N_out(consumed_N_out),

//         .valid_out(reducer_valid_out),
//         .data_block_out(reducer_block_out)
//     );
// endmodule
// `default_nettype wire