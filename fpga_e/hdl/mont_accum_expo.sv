module mont_accum_expo #(
    parameter REGISTER_SIZE = 32,
    parameter BITS_IN_NUM = 4096
) (
    input wire clk_in,
    input wire rst_in,

    input wire [REGISTER_SIZE-1:0] n_squared_in,
    input wire [REGISTER_SIZE-1:0] k_in,
    input wire n_bit_in,
    input wire [REGISTER_SIZE-1:0] reduced_modulo_block_in,
    input wire valid_in,

    output logic consumed_k_out,
    output logic consumed_n_squared_out,
    output logic consumed_n_out,
    output logic valid_out,
    output logic[REGISTER_SIZE-1:0] data_out

);

logic [REGISTER_SIZE-1:0]  reduced_square_out;
logic squared_valid_out;
montgomery_squarer_stream #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(BITS_IN_NUM/2), // nico wrote it as bits in n although that is sussy
    .R(BITS_IN_NUM)
) montgomery_squarer_stream_inst(
    .clk_in(clk_in),
    .rst_in(rst_in ||valid_out),
    .N_in(n_squared_in),
    .k_in(k_in),
    .reduced_modulo_block_in(reduced_modulo_block_in),
    .data_valid_in(valid_in),
    .consumed_k_out(consumed_k_out),
    .consumed_N_out(consumed_n_squared_out),
    .reduced_square_out(reduced_square_out),
    .squared_valid_out(squared_valid_out)
);


mont_accumulator #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(BITS_IN_NUM),
    .R(BITS_IN_NUM)
) mont_accumulator_inst (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .valid_in(squared_valid_out),
    .n_bit_in(n_bit_in),  
    .n_squared_in(n_squared_in),
    .k_in(k_in),
    .squarer_streamer_in(reduced_square_out), 
    .valid_out(valid_out),
    .data_out(data_out),
    .consumed_n_out(consumed_n_out),
    .consumed_k_out(),
    .consumed_n_squared_out(),
    .mult_out(),
    .mult_valid(),
    .cycles_between_sends()
);

    



endmodule










