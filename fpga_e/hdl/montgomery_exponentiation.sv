module montgomery_exponentiation #(
    parameter REGISTER_SIZE = 32,
    parameter BITS_IN_NUM = 4096,
    parameter R  = 4096
) (
    input wire clk_in,
    input wire rst_in,

    input wire [REGISTER_SIZE-1:0] n_squared_in,
    input wire [REGISTER_SIZE-1:0] k_in,
    input wire n_bit_in,
    input wire [REGISTER_SIZE-1:0] random_in,
    input wire valid_in,

    output logic consumed_k_out,
    output logic consumed_n_squared_out,
    output logic consumed_n_out,
    output logic valid_out,
    output logic[REGISTER_SIZE-1:0] data_out
);

logic [REGISTER_SIZE-1:0] random_dupmontified;
logic random_dupmontified_valid;

logic k_fetcher1;
logic k_fetcher2;
logic n_squared_fetcher1;
logic n_squared_fetcher2;
assign consumed_k_out = k_fetcher1|| k_fetcher2;
assign consumed_n_squared_out = n_squared_fetcher1|| n_squared_fetcher2;


mont_caster  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(BITS_IN_NUM)
    )
    stage_1
    (
        .n_in(random_in),
        .valid_in(valid_in),
        .rst_in(rst_in),
        .clk_in(clk_in),
        .data_out(random_dupmontified),
        .valid_out(random_dupmontified_valid),
        .final_out(),
        .ready_out()
    );
logic [REGISTER_SIZE-1:0] true_casted_data;
logic casted_valid;
localparam NUM_BLOCKS = 2*BITS_IN_NUM / REGISTER_SIZE;

 montgomery_reduce #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS(NUM_BLOCKS),
    .R(R)
 ) stage_2 (
    .clk_in(clk_in),
    .rst_in(rst_in),

    .valid_in(random_dupmontified_valid),
    .T_block_in(random_dupmontified),   // the number we want to reduce
    
    .k_constant_block_in(k_in), // we implement in top level so k_constant_block_in is initialized to the first block and increments when consumed_k is set to 1
    .consumed_k_out(k_fetcher1),
    
    .modN_constant_block_in(n_squared_in),
    .consumed_N_out(n_squared_fetcher1),

    .valid_out(casted_valid),
    .data_block_out(true_casted_data),
    .final_out()
);


mont_accum_expo #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(BITS_IN_NUM)
) result_computer (
    .clk_in(clk_in),
    .rst_in(rst_in),

    .n_squared_in(n_squared_in),
    .k_in(k_in),
    .n_bit_in(n_bit_in),
    .reduced_modulo_block_in(true_casted_data),
    .valid_in(casted_valid),

    .consumed_k_out(k_fetcher2),
    .consumed_n_squared_out(n_squared_fetcher2),
    .consumed_n_out(consumed_n_out),
    .valid_out(valid_out),
    .data_out(data_out)
);





    



endmodule










