`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
   input wire          clk_100mhz,
   input wire          [1:0] btn
   );

  logic   sys_rst;
  assign sys_rst = btn[0];
  assign start = btn[1];
  localparam REGISTER_SIZE = 32;
  localparam PRIME_SIZE = 1024;
  localparam N_SIZE = 2*PRIME_SIZE;
  localparam G_SIZE = N_SIZE;
  localparam N_SQUARED_SIZE = 2*N_SIZE;
  localparam R_SIZE = $clog2(N_SQUARED_SIZE) + 1;
  localparam R_SQUARED_MOD_SIZE = N_SQUARED_SIZE;
  localparam K_SIZE = N_SQUARED_SIZE;
  localparam T_SIZE = 2*N_SQUARED_SIZE;


  // for decryption
  //localparam LAMBDA_SIZE = N_SIZE;
  // localparam MU = N_SIZE


localparam NUM_N_BLOCKS = N_SIZE/REGISTER_SIZE;
localparam NUM_G_BLOCKS = G_SIZE/REGISTER_SIZE;
localparam NUM_N_SQUARED_BLOCKS = N_SQUARED_SIZE/REGISTER_SIZE;
localparam NUM_R_SQUARED_BLOCKS =  R_SQUARED_MOD_SIZE/REGISTER_SIZE;
localparam NUM_K_BLOCKS = K_SIZE/REGISTER_SIZE;
localparam NUM_T_BLOCKS = T_SIZE/REGISTER_SIZE;



logic [$clog2(NUM_N_BLOCKS)-1:0][REGISTER_SIZE-1:0] n;
logic [$clog2(NUM_G_BLOCKS)-1:0][REGISTER_SIZE-1:0] g; 
logic [$clog2(NUM_N_SQUARED_BLOCKS)-1:0][REGISTER_SIZE-1:0] n_squared;
 logic [$clog2(NUM_R_SQUARED_BLOCKS)-1:0][REGISTER_SIZE-1:0]r_squared; 
 logic [$clog2(NUM_K_BLOCKS)-1:0][REGISTER_SIZE-1:0] k;


logic [R_SIZE-1:0] r; 
assign r = N_SQUARED_SIZE; 


// We are assuming we are sending the bits in lsb first order





  
  logic valid_data;
  logic [7:0] data_received_byte;
  



  uart_receive #(
    .INPUT_CLOCK_FREQ(100_000_000), // may change
    .BAUD_RATE(57600)
  ) laptop_encryptor_uart
  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .rx_wire_in(), //TODO
    .new_data_out(valid_data),
    .data_byte_out(data_received_byte)
  );

  // (Future: voterID)
  // (Future: more bytes for checking vote)

logic candidate_vote;
logic valid_vote_out;

vote_processor #(

) process_vote(
  .clk_in(clk_100mhz),
  .rst_in(sys_rst),
  .valid_in(valid_data),
  .new_byte_in(data_received_byte),
  .vote_out(candidate_vote),
  .valid_vote_out(valid_vote_out)
);
logic [REGISTER_SIZE-1:0] random_block;
logic random_valid;

// generates a 4096 bit output in register size sizes, but the topmost 2048 bits are 0
rand_gen#(
  .BITSIZE(REGISTER_SIZE)
) 
rng
(
  .clk_in(clk_100mhz),
  .rst_in(sys_rst),
  .trigger_in(valid_vote_out),
  .rand_out(random_block),
  .valid_out(random_valid)
);

logic[$clog2(NUM_R_SQUARED_BLOCKS)-1:0] r_squared_select_index;
logic[REGISTER_SIZE-1:0] r_squared_mod_select_out;
assign r_squared_mod_select_out = r_squared[r_squared_select_index];
evt_counter #(.MAX_COUNT(NUM_R_SQUARED_BLOCKS))
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(random_valid),
    .count_out(r_squared_mod_select_out)
  );


logic [REGISTER_SIZE-1:0] placeholder1_mult_out;
logic placeholder1_mult_valid_out;
fsm_multiplier  #(
    .register_size(REGISTER_SIZE),
    .bits_in_num(R_SQUARED_MOD_SIZE)
    )
entry_multplier
    (
        .n_in(random_block),
        .m_in(r_squared_mod_select_out),
        .valid_in(random_valid),
        .rst_in(sys_rst),
        .clk_in(clk_100mhz),
        .data_out(placeholder1_mult_out),
        .valid_out(placeholder1_mult_valid_out),
    );


logic[$clog2(NUM_N_SQUARED_BLOCKS)-1:0] n_squared_select_index;
logic[REGISTER_SIZE-1:0] n_squared_select_out;
assign n_squared_select_out = n_squared[n_squared_select_index];

logic[$clog2(NUM_K_BLOCKS)-1:0] k_select_index;
logic[REGISTER_SIZE-1:0] k_select_out;
assign k_select_out = k[k_select_index];

logic consumed_n_squared_out;

evt_counter #(.MAX_COUNT(NUM_N_SQUARED_BLOCKS))
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(consumed_n_squared_out),
    .count_out(n_squared_select_out)
  );
  evt_counter #(.MAX_COUNT(NUM_K_BLOCKS))
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(placeholder1_mult_valid_out),
    .count_out(k_select_out)
  );


logic [REGISTER_SIZE-1:0] reduced_product_block;
logic placeholder_reduce_valid1;
  montgomery_reduce#(
    .register_size(REGISTER_SIZE),
    .num_blocks(NUM_T_BLOCKS),
  ) reducer1(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .valid_in(placeholder1_mult_valid_out),
    .product_t_in(placeholder1_mult_out),
    .k_in(k_select_out),
    .n_squared_in(n_squared_select_out),
    .consumed_n_squared_out(consumed_n_squared_out),
    .data_out(reduced_product_block),
    .valid_out(placeholder_reduce_valid1)
)
    


    



endmodule // top_level


`default_ne

