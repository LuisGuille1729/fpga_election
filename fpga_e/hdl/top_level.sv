`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    input wire          clk_100mhz,
    input wire          [2:0] btn,
    input wire 				 uart_rxd,

    output logic [0:0] copi,
    output logic [0:0] dclk,
    output logic [0:0] cs,

    output logic uart_txd,

    output logic [15:0] led,
    output logic [2:0] rgb0, 
    output logic [2:0] rgb1
  );
  assign rgb0 = 0;
  assign rgb1 = 0;


  logic   sys_rst;
  assign sys_rst = btn[0];


  // CONSTANTS VALUES  
  // localparam N_VALUE = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767
  // actually, only store g for the encryptor. For the decryptor we will store n (but in BRAM)

  // SIZES
  localparam REGISTER_SIZE = 32;
  localparam PRIME_SIZE = 1024;
  localparam N_SIZE = 2*PRIME_SIZE;
  localparam N_SQUARED_SIZE = 2*N_SIZE;
  localparam K_SIZE = N_SQUARED_SIZE;
  localparam T_SIZE = 2*N_SQUARED_SIZE;


  // for decryption
  //localparam LAMBDA_SIZE = N_SIZE;
  // localparam MU = N_SIZE

  // AMOUNT OF BLOCKS PER CONSTANT
  localparam NUM_N_BLOCKS = N_SIZE/REGISTER_SIZE;
  localparam NUM_N_SQUARED_BLOCKS = N_SQUARED_SIZE/REGISTER_SIZE;
  localparam NUM_K_BLOCKS = K_SIZE/REGISTER_SIZE;
  localparam NUM_T_BLOCKS = T_SIZE/REGISTER_SIZE;


  logic [NUM_N_BLOCKS-1:0][REGISTER_SIZE-1:0] n;
  logic [NUM_N_SQUARED_BLOCKS-1:0][REGISTER_SIZE-1:0] n_squared; 
  logic [NUM_K_BLOCKS-1:0][REGISTER_SIZE-1:0] k;


  // old verilog constructs for usage of readmemh. No workarounds from our knowledge :( 
  reg [REGISTER_SIZE-1:0] temp_array_n[NUM_N_BLOCKS-1:0];
  reg [REGISTER_SIZE-1:0] temp_array_n_squared[NUM_N_SQUARED_BLOCKS-1:0];
  reg [REGISTER_SIZE-1:0] temp_array_k[NUM_N_SQUARED_BLOCKS-1:0];

  initial begin
      $readmemh("n.mem", temp_array_n); // Read into the temporary array
      for (int i = 0; i < NUM_N_BLOCKS; i++) begin
          n[i] = temp_array_n[i];          // Map values to the multi-dimensional array
      end
      $readmemh("n_squared.mem", temp_array_n_squared); // Read into the temporary array
      $readmemh("k.mem", temp_array_k); // Read into the temporary array
      for (int i = 0; i < NUM_N_SQUARED_BLOCKS; i++) begin
          n_squared[i] = temp_array_n_squared[i];          // Map values to the multi-dimensional array
          k[i] = temp_array_k[i];
      end

  end

  

  logic uart_rxd_piped2;
  pipeliner #(
    .PIPELINE_STAGE_COUNT(2),
    .DATA_BIT_SIZE(1)
  ) uart_pipeline
    (
        .clk_in(clk_100mhz),
        .rst_in(sys_rst),
        .data_in(uart_rxd),
        .data_out(uart_rxd_piped2)
    );

  // UART Receive
  logic valid_data;
  logic [7:0] data_received_byte;

  uart_receive #(
    .INPUT_CLOCK_FREQ(100_000_000), // may change
    .BAUD_RATE(4800)
  ) laptop_encryptor_uart
  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .rx_wire_in(uart_rxd_piped2), 
    .new_data_out(valid_data),
    .data_byte_out(data_received_byte)
  );

  always_ff @( posedge clk_100mhz) begin
    if (sys_rst) begin

      led[0] <= 0;
      led[1] <= 0;
      led[2] <= 0;
      led[3] <= 0;
      led[4] <= 0;
      led[5] <= 0;
      led[6] <= 0;
      led[7] <= 0;
      led[8] <= 0;

    end
    else begin
      led[0] <= (valid_data) ? 1'b1 : led[0];
      led[1] <= (valid_data) ? data_received_byte[0] : led[1];
      led[2] <= vote_procesor_states == TERMINAL;
      led[3] <= random_valid? 1: led[3];
      led[4] <= expo_valid? 1: led[4];
      led[5] <= candidate_valid? 1: led[5];
      led[6] <= storage_valid? 1: led[6];
      led[7] <= data_pe_valid? 1: led[7];
      led[8] <= trigger_uart_send? 1: led[8];
    end

  end


  // For now we only send the candidate number
  // (Future: voterID)
  // (Future: more bytes for checking vote)

//begin processing votes  button
logic begin_processing;
assign begin_processing = btn[1];
enum  {IDLE,TRIGGERED, TERMINAL } vote_procesor_states;
logic restart_processor;
assign restart_processor = btn[2];
always_ff @( posedge clk_100mhz ) begin
  if (sys_rst)begin
    vote_procesor_states<= IDLE;
  end else begin
    case (vote_procesor_states)
      IDLE: vote_procesor_states <= begin_processing? TRIGGERED: IDLE;
      TRIGGERED: vote_procesor_states <= TERMINAL; 
      TERMINAL: vote_procesor_states <= restart_processor? IDLE: TERMINAL;
    endcase
  end
end


  // PROCESS VOTE
  logic candidate_vote;
  logic valid_processed_vote;
  logic request_new_vote;

  vote_processor #(

  ) process_vote(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .valid_in(valid_data),
    .request_new_vote(request_new_vote || vote_procesor_states ==  TRIGGERED),
    .new_byte_in(data_received_byte),
    .vote_out(candidate_vote),
    .valid_vote_out(valid_processed_vote)
  );

  // GENERATE RANDOM NUMBER
  logic [REGISTER_SIZE-1:0] random_block;
  logic random_valid;

  // generates a 4096 bit output in register size sizes, but the topmost 2048 bits are 0
  LFSR32Fake#()
  rng_stream
  (
    .rst_in(sys_rst),
    .clk_in(clk_100mhz),
    .trigger_in(valid_processed_vote),
    .rand_out(random_block),
    .valid_out(random_valid)
  );

  logic [REGISTER_SIZE-1:0] expo_n_squared_in;
  logic [REGISTER_SIZE-1:0] expo_k_in;
  logic n_bit_in;
  logic expo_consumed_k_out;
  logic expo_consumed_n_squared_out;
  logic consumed_n_out;


  logic expo_valid;
  logic[REGISTER_SIZE-1:0] expo_data_out;
  montgomery_exponentiation #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(N_SQUARED_SIZE),
    .R(4096)
  ) expo 
(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),

    .n_squared_in(expo_n_squared_in),
    .k_in(expo_k_in),
    .n_bit_in(n_bit_in),
    .random_in(random_block),
    .valid_in(random_valid),

    .consumed_k_out(expo_consumed_k_out),
    .consumed_n_squared_out(expo_consumed_n_squared_out),
    .consumed_n_out(consumed_n_out),
    .valid_out(expo_valid),
    .data_out(expo_data_out)
);


logic [REGISTER_SIZE-1:0] candidate_n_squared_in;
logic [REGISTER_SIZE-1:0] candidate_k_in;
logic candidate_consumed_k_out;
logic candidate_consumed_n_squared_out;


logic candidate_valid;
logic[REGISTER_SIZE-1:0] candidate_parsed_data_out;
candidate_encryptor  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(N_SQUARED_SIZE),
    .R(4096)
) encryptorator
 (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .n_squared_in(candidate_n_squared_in),
    .k_in(candidate_k_in),
    .exponentiator_in(expo_data_out),
    .valid_in(expo_valid),
    .candidate_in(candidate_vote),
    .consumed_k_out(candidate_consumed_k_out),
    .consumed_n_squared_out(candidate_consumed_n_squared_out),
    .consumed_vote_out(request_new_vote),
    .valid_out(candidate_valid),
    .data_out(candidate_parsed_data_out)
);


logic request_next_repeater_input;
logic [REGISTER_SIZE-1:0] storage_read;
logic storage_valid;
redstone_repeater #(
        .BITS_IN_NUM(N_SQUARED_SIZE),
        .REGISTER_SIZE(REGISTER_SIZE)
) spi_storage(
        .clk_in(clk_100mhz),
        .rst_in(sys_rst),

        .data_in(candidate_parsed_data_out),
        .data_valid_in(candidate_valid),
        .prev_data_consumed_in(request_next_repeater_input),
        .data_out(storage_read),
        .data_valid_out(storage_valid)
    );

spi_con #(
      .DATA_WIDTH(REGISTER_SIZE),
      .DATA_CLK_PERIOD(100)
      )
      spi_transmitter
      (
        .clk_in(clk_100mhz), //system clock (100 MHz)
        .rst_in(sys_rst), //reset in signal
        .data_in(storage_read), //data to send
        .trigger_in(storage_valid), //start a transaction
        .data_out(), //data received!
        .data_valid_out(), //high when output data is present.
 
        .chip_data_out(copi), //(serial dout preferably)
        .chip_data_in(), //(serial din preferably)
        .chip_clk_out(dclk),
        .chip_sel_out(cs),
        .ready_out(request_next_repeater_input)
      );


    assign led[15] = request_next_repeater_input;




// *************** FOR TESTING IN ISOLATION, WITHOUT DECRYPTOR FPGA ********************** //



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




// module byte_repeater  #(
//     parameter REGISTER_SIZE = 32,
//     parameter BITS_IN_NUM = 4096
//     )
//     (
//         input wire [REGISTER_SIZE-1:0] data_in,
//         input wire valid_in,
//         input wire request_next_byte_in,
//         input wire rst_in,
//         input wire clk_in,
//         output logic [7:0] data_out,
//         output logic valid_out
//     );

  byte_repeater #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(4096)
  )
  translate_spi_blocks
  (
    .rst_in(sys_rst),
    .clk_in(clk_100mhz),

    .data_in(data_pe_received),
    .valid_in(data_pe_valid),

    .request_next_byte_in(!uart_tx_busy),
    .valid_out(trigger_uart_send),
    .data_out(byte_to_send)
  );


  logic uart_tx_busy;
  logic trigger_uart_send;
  logic byte_to_send;

  uart_transmit #(.BAUD_RATE(4800)) 
  fpga_to_pc_uart  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .data_byte_in(byte_to_send),
    .trigger_in(trigger_uart_send),
    .busy_out(uart_tx_busy),
    .tx_wire_out(uart_txd)
  );




// *************** (END TESTING IN ISOLATION WITHOUT DECRYPTOR FPGA) ********************** //


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


  logic[$clog2(NUM_N_SQUARED_BLOCKS)-1:0] candidate_n_squared_select_index;
  evt_counter #(.MAX_COUNT(NUM_N_SQUARED_BLOCKS))
  cand_n_squared_block_select
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(candidate_consumed_n_squared_out),
    .count_out(candidate_n_squared_select_index)
  );

  assign candidate_n_squared_in = n_squared[candidate_n_squared_select_index];

  
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




  logic[$clog2(NUM_K_BLOCKS)-1:0] cand_k_select_index;
  evt_counter #(.MAX_COUNT(NUM_K_BLOCKS))
  cand_k_block_select
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(candidate_consumed_k_out),
    .count_out(cand_k_select_index)
  );
  assign candidate_k_in = k[cand_k_select_index];


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

