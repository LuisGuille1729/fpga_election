`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    input wire          clk_100mhz,
    input wire          [1:0] btn,
    input wire [0:0] copi,
    output logic 				 uart_txd,
    output logic [0:0] dclk,
    output logic [0:0] cs,
    output logic [15:0] led,
    output logic [2:0] rgb0, 
    output logic [2:0] rgb1
  );

  logic   sys_rst;
  assign sys_rst = btn[0];
  logic compute_tally;
  assign compute_tally = btn[1];
  assign led = 0;
  assign rgb0 =0;
  assign rgb1 = 0;
enum {VOTING, RESULTS} load_states;
  always_ff @( posedge clk_100mhz ) begin 
    if (sys_rst) begin
      load_states<= VOTING;
    end else if (compute_tally) begin
      load_states <= RESULTS;
    end
  end


  // localparam N_SQUAR
  // In the Decryptor only:
  // to use one less divider, store 
  // Q_SQAURED_MOD_N where Q = 2**2048
  // Need to store n as well, probably in dram 

  // SIZES
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

  // AMOUNT OF BLOCKS PER CONSTANT
  localparam NUM_N_BLOCKS = N_SIZE/REGISTER_SIZE;
  localparam NUM_G_BLOCKS = G_SIZE/REGISTER_SIZE;
  localparam NUM_N_SQUARED_BLOCKS = N_SQUARED_SIZE/REGISTER_SIZE;
  localparam NUM_R_SQUARED_BLOCKS =  R_SQUARED_MOD_SIZE/REGISTER_SIZE;
  localparam NUM_K_BLOCKS = K_SIZE/REGISTER_SIZE;
  localparam NUM_T_BLOCKS = T_SIZE/REGISTER_SIZE;






// old verilog constructs for usage of readmemh. No workarounds from our knowledge :( 
reg [REGISTER_SIZE-1:0] n[NUM_N_BLOCKS-1:0];
reg [REGISTER_SIZE-1:0] n_squared[NUM_N_SQUARED_BLOCKS-1:0];
reg [REGISTER_SIZE-1:0] k[NUM_N_SQUARED_BLOCKS-1:0];

initial begin
    $readmemh("lambda.mem", n); // Read into the temporary array
    $readmemh("n_squared.mem", n_squared); // Read into the temporary array
    $readmemh("k.mem", k); // Read into the temporary array
end









logic [REGISTER_SIZE-1:0] data_pe_received;
logic data_pe_valid;

spi_pe
  #(
    .DATA_WIDTH(REGISTER_SIZE)
  ) my_spi_pe
  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),

    // data to send (CIPO)    
    .data_in(),
    .valid_in(),

    // received data (COPI)
    .data_out(data_pe_received),
    .data_valid_out(data_pe_valid),

    // C P signals
    .chip_data_in(copi), //(COPI)
    .chip_data_out(), //(CIPO)
    .chip_clk_in(dclk), //(DCLK)
    .chip_sel_in(cs) // (CS) 
  );
  





logic [REGISTER_SIZE-1:0] accumed_data;
logic valid_cypher_text;

logic read_next;

assign read_next =  data_pe_valid; //todo modify for the unleash wrath later;


bram_blocks_rw_flush_extended #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS(NUM_N_SQUARED_BLOCKS),
    .INIT_FILE("temp.mem")     
)
vote_accumulator
 (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .read_next_block_valid_in(read_next), 
    .read_block_out(accumed_data),
    .read_block_pipe2_valid_out(),
    .flush(load_states==RESULTS),
    .flush_valid(valid_cypher_text),
    .read_done_all_blocks_pipe2_out(), // pipelined as well
    .read_requested_for_last_block(), // unpiped
    .write_next_block_valid_in(accumulator_valid),
    .write_block_in(accumulator_parsed_data_out)
);



logic[REGISTER_SIZE-1:0] accum_mul_out;
logic accum_mul_valid;

fsm_multiplier  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(N_SQUARED_SIZE)
    )
    accumulator_multiplier
    (
        .n_in(accumed_data),
        .m_in(data_pe_received),
        .valid_in(data_pe_valid),
        .rst_in(sys_rst),
        .clk_in(clk_100mhz),
        .data_out(accum_mul_out),
        .valid_out(accum_mul_valid),
        .final_out(),
        .ready_out()
    );



logic [REGISTER_SIZE-1:0] accumulator_n_squared_in;
logic [REGISTER_SIZE-1:0] accumulator_k_in;
logic accumulator_consumed_k_out;
logic accumulator_consumed_n_squared_out;
logic accumulator_valid;
logic[REGISTER_SIZE-1:0] accumulator_parsed_data_out;


  montgomery_reduce #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS(NUM_T_BLOCKS),
    .R(4096)
  ) accum_reducer (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .valid_in(accum_mul_valid),
    .T_block_in(accum_mul_out),   // the number we want to reduce
    
    .k_constant_block_in(accumulator_k_in), // we implement in top level so k_constant_block_in is initialized to the first block and increments when consumed_k is set to 1
    .consumed_k_out(accumulator_consumed_k_out),
    
    .modN_constant_block_in(accumulator_n_squared_in),
    .consumed_N_out(accumulator_consumed_n_squared_out),

    .valid_out(accumulator_valid),
    .data_block_out(accumulator_parsed_data_out),
    .final_out()
);



logic [REGISTER_SIZE-1:0] expo_n_squared_in;
logic [REGISTER_SIZE-1:0] expo_k_in;
logic[REGISTER_SIZE-1:0] expo_data_out;

logic n_bit_in;
logic expo_consumed_k_out;
logic expo_consumed_n_squared_out;
logic consumed_n_out;
logic expo_valid;

mont_accum_expo #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(N_SQUARED_SIZE)
) (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),

    .n_squared_in(expo_n_squared_in),
    .k_in(expo_k_in),
    .n_bit_in(n_bit_in),
    .reduced_modulo_block_in(accumed_data),
    .valid_in(valid_cypher_text),

    .consumed_k_out(expo_consumed_k_out),
    .consumed_n_squared_out(expo_consumed_n_squared_out),
    .consumed_n_out(consumed_n_out),
    .valid_out(expo_valid),
    .data_out(expo_data_out)
);

logic[REGISTER_SIZE-1:0] padded_data;
logic padder_valid;
padder  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(N_SQUARED_SIZE),
    .NUM_PADS(N_SQUARED_SIZE)
    )
    (
        .data_in(expo_data_out),
        .valid_in(expo_valid),
        .rst_in(sys_rst),
        .clk_in(clk_100mhz),
        .data_out(padded_data),
        .valid_out(padder_valid)
    );

logic [REGISTER_SIZE-1:0] final_red_k_in;
logic [REGISTER_SIZE-1:0] final_red_n_squared_in;
logic final_red_consumed_k_out;
logic final_red_consumed_n_squared_out;

logic final_reduce_valid;
logic [REGISTER_SIZE-1:0] final_reduce_data;

montgomery_reduce #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS(NUM_T_BLOCKS),
    .R(4096)
) (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),

    .valid_in(padder_valid),
    .T_block_in(padded_data),   // the number we want to reduce
    
    .k_constant_block_in(final_red_k_in), // we implement in top level so k_constant_block_in is initialized to the first block and increments when consumed_k is set to 1
    .consumed_k_out(final_red_consumed_k_out),
    
    .modN_constant_block_in(final_red_n_squared_in),
    .consumed_N_out(final_red_consumed_n_squared_out),

    .valid_out(final_reduce_valid),
    .data_block_out(final_reduce_data),
    .final_out()
);




logic [REGISTER_SIZE-1:0] subtracted_data;
logic  subtracted_valid;
logic [REGISTER_SIZE-1:0] subtract_one_const = -1;
//by adding 1111111 ... 1 it is equivalent to subtracting 1
great_adder  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(N_SQUARED_SIZE)
    )
    (
        .a_in(final_reduce_data),
        .b_in(subtract_one_const),
        .carry_in(0),
        .valid_in(final_reduce_valid),
        .rst_in(sys_rst),
        .clk_in(clk_100mhz),
        .data_out(subtracted_data),
        .carry_out(),
        .valid_out(subtracted_valid),
        .final_out()
    );
logic [REGISTER_SIZE-1:0] divider_data;
logic divider_valid;
fixed_divider #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS_IN(NUM_N_SQUARED_BLOCKS),
    // idk what this parameter does
    // .BITS_EXPONENT(6080), // only change if changing divider n
    .NUM_BLOCKS_OUT(NUM_N_BLOCKS)
)(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),

    .valid_in(subtracted_valid),
    .x_block_in(subtracted_data), 
    .valid_out(divider_valid),
    .data_block_out(divider_data)
);

logic [REGISTER_SIZE-1:0]  mu_multiplier_data;
logic mu_multiplier_valid;
mu_multiplier  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(N_SIZE)
    )
    muultiplier
    (
        .n_in(divider_data),
        .valid_in(divider_valid),
        .rst_in(sys_rst),
        .clk_in(clk_100mhz),
        .data_out(mu_multiplier_data),
        .valid_out(mu_multiplier_valid),
        .final_out(),
        .ready_out()
    );

    logic [REGISTER_SIZE-1:0] modder_data;
    logic modder_valid;
    mod_n  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(N_SQUARED_SIZE)
    )
    final_modder
    (
        .num_in(mu_multiplier_data),
        .valid_in(mu_multiplier_valid),
        .rst_in(sys_rst),
        .clk_in(clk_100mhz),
        .data_out(modder_data),
        .valid_out(modder_valid)
    );

    
  byte_repeater #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(N_SQUARED_SIZE)
  )
  translate_spi_blocks
  (
    .rst_in(sys_rst),
    .clk_in(clk_100mhz),
    // .data_in(modder_data),
    // .valid_in(modder_valid),
    // .data_in(expo_data_out),
    // .valid_in(expo_valid),
    .data_in(accumed_data),
    .valid_in(valid_cypher_text),

    .request_next_byte_in(!uart_tx_busy),
    .valid_out(trigger_uart_send),
    .data_out(byte_to_send)
  );


  logic uart_tx_busy;
  logic trigger_uart_send;
  logic[7:0] byte_to_send;

  uart_transmit #(.BAUD_RATE(4800)) 
  fpga_to_pc_uart  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .data_byte_in(byte_to_send),
    .trigger_in(trigger_uart_send),
    .busy_out(uart_tx_busy),
    .tx_wire_out(uart_txd)
  );

  

  

  // [Multiplier Block Select Counter]
  // R_SQUARED Block Select



  // [Montgomery Reduction Block Select Counters] 
  // N_SQUARED Block Select
  logic[$clog2(NUM_N_SQUARED_BLOCKS)-1:0] expo_n_squared_select_index;
  evt_counter #(.MAX_COUNT(NUM_N_SQUARED_BLOCKS))
  expo_n_squared_block_select
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(expo_consumed_n_squared_out),
    .count_out(expo_n_squared_select_index)
  );
  assign expo_n_squared_in = n_squared[expo_n_squared_select_index];


  logic[$clog2(NUM_N_SQUARED_BLOCKS)-1:0] accumulator_n_squared_select_index;
  evt_counter #(.MAX_COUNT(NUM_N_SQUARED_BLOCKS))
  accum_n_squared_block_select
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(accumulator_consumed_n_squared_out),
    .count_out(accumulator_n_squared_select_index)
  );

  assign accumulator_n_squared_in = n_squared[accumulator_n_squared_select_index];

  
  // K Block Select
  logic[$clog2(NUM_K_BLOCKS)-1:0] expo_k_select_index;
  evt_counter #(.MAX_COUNT(NUM_K_BLOCKS))
  expo_k_block_select
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(expo_consumed_k_out),
    .count_out(expo_k_select_index)
  );
  assign expo_k_in = k[expo_k_select_index];




  logic[$clog2(NUM_K_BLOCKS)-1:0] accum_k_select_index;
  evt_counter #(.MAX_COUNT(NUM_K_BLOCKS))
  accum_k_block_select
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(accumulator_consumed_k_out),
    .count_out(accum_k_select_index)
  );
  assign accumulator_k_in = k[accum_k_select_index];


  logic[$clog2(NUM_N_BLOCKS)-1:0] n_block_select_index;
  evt_counter #(
    .MAX_COUNT(NUM_N_BLOCKS)
  )
  
  n_block_select
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst || (n_inner_block_bit_select_index == (REGISTER_SIZE-1) && (n_block_select_index == NUM_N_BLOCKS-1))),
    .evt_in(consumed_n_out && n_inner_block_bit_select_index == (REGISTER_SIZE-1)),
    .count_out(n_block_select_index)
  );

  logic [$clog2(REGISTER_SIZE)-1:0] n_inner_block_bit_select_index;
  evt_counter #(.MAX_COUNT(REGISTER_SIZE))
  n_inner_block_bit_select
  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(consumed_n_out),
    .count_out(n_inner_block_bit_select_index)
  );


  assign n_bit_in = n[n_block_select_index][n_inner_block_bit_select_index];













    


    



endmodule // top_level

`default_nettype wire

