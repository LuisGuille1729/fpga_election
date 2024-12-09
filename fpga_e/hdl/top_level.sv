`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    input wire          clk_100mhz,
    input wire          [0:0] btn,
    input wire 				 uart_rxd,
    output logic [0:0] copi,
    output logic [0:0] dclk,
    output logic [0:0] cs
  );

  logic   sys_rst;
  assign sys_rst = btn[0];


  // CONSTANTS VALUES  
  // localparam N_VALUE = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767
  // actually, only store g for the encryptor. For the decryptor we will store n (but in BRAM)

  // localparam N_SQUARED_VALUE = 590422124689825055380819807609388189571256327875045759413123457324012204244904348160287525082997271790713457882660955619888946254261043203027771593298628441011612035265723835242026121235268765066944326490013942087806775580532770419185006727693836762421126549971166777350187227849036747874498748898200371278162103260529601535123784241275436339520934294087305771785057763906429748321306960060302877347805301757220204940169408640087558461307977499958542938818185362073916109749225361753465488257725527781630462231753011771059924172480693534542047579157001196799192378909460518139302358557373319671729492711810667118192183711386265644011686234954732739561715352966757275591394362051763747096082775428034331257483730208748244296931348278644467996131508327249311248703598496538092607531165259331139922697302096359403581744626882396938437309021732688016235359847356456980294356847006056239507114391778248012879303412205211396556204524145521662064393273536726990926093148343745926511722322805650194868790817814574744175510423873562280366546710025852968180416945163684882551407895812254630573660655532948916284348570078749620871743294686585436504822696481572626713064081970623249985910047616445949491493081152698162104745221931251546873892289
  // localparam K_VALUE = 143470092535370572884762559577261597060726098095130651285005957313214286020208846248841066413839665875461265127305468068675031009431615257076642373897015244136524563555490527907489468206900169957371718405066201235672090362478853663742336475964379108870711218822319915578568841927832446909576170206724004148662014335256366686051416432871380265066096266104993996707561049975588005673291226873645650089976222132906287395873762164927828399409677542706610136520339776715033573328301612875290174288048957888104513170905651338622165968798603889655834913370256159826940403775407788986108836704031341025569895498152471030201955294429901239594071770739717406269774068252071820981877376647344316707332724263561803448778502843622405588443134412694906949791848247581439427186190448488327675794671096010372437761696016989799470309941546670264823723175030798254161797471206863652908093391507702691498503852245524787840057862796014700934951893477680960594052882015846665426104688827909670722048223991884739539367655706233535869616672961157302847254190896924514009866479293385406880250829014263662616828841246401389608022822438266332289468984960397434107372764152486555063086719771617731206415603770119148562143343177455545346632889001702426541456831
  // localparam LAMBDA_VALUE = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959964955464479024933422992909635397164311546361372532118006196725814332208510070121559031989216338031857983916010030668064205891373472234326096586015391335681399251733336672726683199532344809536988586555705039782732792395990414225992198743278061328019762865406265480992968614844386447881974648024301034133270890160
  // localparam MU_VALUE = 8915567752383628781438898187002797896548025900480737799095311841381836545755198503892372879726878495151035115946986868458012154448649583896132194358560329782831378798600255894543884351748301246095759638231762423081258773261447078148315461663411905258069603207263310818435311223030456445831047816378110749327580484779512120318259491191211823394214832953187276053506207701544252431583335833161276475407653180651152186091635887389297141653769732662414014629608293223179202238133723709179125878839638929208525481449388861597926415145013669009524453207751806355956198029749591583141643408193028947053783351959727470281524

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

  



  logic used_bit;
  pipeliner  #(
    .PIPELINE_STAGE_COUNT(2),
    .DATA_BIT_SIZE(1)
    )
    (
        .clk_in(clk_100mhz),
        .rst_in(sys_rst),
        .data_in(uart_rxd),
        .data_out(used_bit)
    );

  // UART Receive
  // We are assuming we are receiving the bits in lsb first order
  logic valid_data;
  logic [7:0] data_received_byte;

  uart_receive #(
    .INPUT_CLOCK_FREQ(100_000_000), // may change
    .BAUD_RATE(57600)
  ) laptop_encryptor_uart
  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .rx_wire_in(used_bit), 
    .new_data_out(valid_data),
    .data_byte_out(data_received_byte)
  );

  // For now we only send the candidate number
  // (Future: voterID)
  // (Future: more bytes for checking vote)

  // PROCESS VOTE
  logic candidate_vote;
  logic valid_processed_vote;
  logic request_new_vote;

  vote_processor #(

  ) process_vote(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .valid_in(valid_data),
    .request_new_vote(request_new_vote),
    .new_byte_in(data_received_byte),
    .vote_out(candidate_vote),
    .valid_vote_out(valid_processed_vote)
  );

  // GENERATE RANDOM NUMBER
  logic [REGISTER_SIZE-1:0] random_block;
  logic random_valid;

  // generates a 4096 bit output in register size sizes, but the topmost 2048 bits are 0
  LFSR32#()
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
) (
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
logic[REGISTER_SIZE-1:0] canidate_parsed_data_out;


candidate_encryptor  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(N_SQUARED_SIZE),
    .R(4096)
) (
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
    .data_out(canidate_parsed_data_out)
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

        .data_in(canidate_parsed_data_out),
        .data_valid_in(candidate_valid),
        .request_next_input(request_next_repeater_input),
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

