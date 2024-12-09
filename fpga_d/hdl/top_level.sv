`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    input wire          clk_100mhz,
    input wire          [1:0] btn,
    output wire 				 uart_txd,
    output logic [0:0] copi,
    output logic [0:0] dclk,
    output logic [0:0] cs
  );

  logic   sys_rst;
  assign sys_rst = btn[0];
  logic compute_tally;
  assign compute_tally = btn[1];
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





  // CONSTANTS INITIALIZATION:
  // logic [$clog2(NUM_N_BLOCKS)-1:0][REGISTER_SIZE-1:0] n;
  // logic [$clog2(NUM_N_SQUARED_BLOCKS)-1:0][REGISTER_SIZE-1:0] n_squared; 
  // logic [$clog2(NUM_K_BLOCKS)-1:0][REGISTER_SIZE-1:0] k;
  logic [NUM_N_BLOCKS-1:0][REGISTER_SIZE-1:0] n;
  logic [NUM_N_SQUARED_BLOCKS-1:0][REGISTER_SIZE-1:0] n_squared; 
  logic [NUM_K_BLOCKS-1:0][REGISTER_SIZE-1:0] k;


// old verilog constructs for usage of readmemh. No workarounds from our knowledge :( 
reg [REGISTER_SIZE-1:0] temp_array_n[NUM_N_BLOCKS-1:0];
reg [REGISTER_SIZE-1:0] temp_array_n_squared[NUM_N_SQUARED_BLOCKS-1:0];
reg [REGISTER_SIZE-1:0] temp_array_k[NUM_N_SQUARED_BLOCKS-1:0];

initial begin
    $readmemh("lambda.mem", temp_array_n); // Read into the temporary array
    for (int i = 0; i < NUM_N_BLOCKS; i++) begin
        n[i] = temp_array_n[i];          // n actually has the value of lambda here. But for easier thought process 
                                          // use n variable
    end
    $readmemh("n_squared.mem", temp_array_n_squared); // Read into the temporary array
    $readmemh("k.mem", temp_array_k); // Read into the temporary array
    for (int i = 0; i < NUM_N_SQUARED_BLOCKS; i++) begin
        n_squared[i] = temp_array_n_squared[i];          // Map values to the multi-dimensional array
        k[i] = temp_array_k[i];
    end
end











logic [REGISTER_SIZE-1:0] spi_data_received;
logic valid_data_received;

spi_pe #(
      .DATA_WIDTH(REGISTER_SIZE)
      )
      spi_receiver
      (
        .clk_in(clk_100mhz), //system clock (100 MHz)
        .rst_in(sys_rst), //reset in signal
        .data_in(), //data to send
        .trigger_in(), //start a transaction
        .data_out(spi_data_received), //data received!
        .data_valid_out(valid_data_received), //high when output data is present.
 
        .chip_data_out(copi), //(serial dout preferably)
        // todo fix these ports later
        .chip_data_in(), //(serial din preferably)
        .chip_clk_out(),
        .chip_sel_out(),
        .ready_out()
      );





logic [REGISTER_SIZE-1:0] accumed_data;
logic valid_cypher_text;

vote_accumulator_wrapper  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BITS_STORED(NUM_N_SQUARED_BLOCKS)
    )
    (
        .block_in(accumulator_parsed_data_out),
        .compute_tally(compute_tally),
        .valid_in(accumulator_valid),
        .request_next_in(valid_data_received),
        .rst_in(sys_rst),
        .clk_in(clk_100mhz),
        .data_out(accumed_data),
        .valid_out(valid_cypher_text)
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
        .m_in(spi_data_received),
        .valid_in(valid_data_received),
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

logic [REGISTER_SIZE-1:0] subtracted_data;
logic  subtracted_valid;
logic [REGISTER_SIZE-1:0] subtract_one_const = -1;
//by adding 1111111 ... 1 it is equivalent to subtracting 1
great_adder  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(N_SQUARED_SIZE)
    )
    (
        .a_in(expo_data_out),
        .b_in(subtract_one_const),
        .carry_in(0),
        .valid_in(expo_valid),
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


//TODO: FIX and ADD MOD BEFORE HERE LATER
    localparam current_baud_rate = 115200;
uart_transmit 
  #(
        .INPUT_CLOCK_FREQ (100_000_000),
        .BAUD_RATE (current_baud_rate)
    )
   (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .data_byte_in(mu_multiplier_data[7:0]),
    .trigger_in(mu_multiplier_valid),
    .busy_out(),
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


  logic[$clog2(NUM_N_BLOCKS)-1:0] n_select_index;
  evt_counter #(.MAX_COUNT(NUM_N_BLOCKS))
  n_block_select
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(consumed_n_out),
    .count_out(n_select_index)
  );
  assign n_bit_in = n[n_select_index];














    


    



endmodule // top_level

`default_nettype wire

