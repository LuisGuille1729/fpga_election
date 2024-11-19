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


  // CONSTANTS VALUES  
  localparam N_VALUE = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767
  localparam G_VALUE = N_VALUE + 1

  localparam N_SQUARED_VALUE = 590422124689825055380819807609388189571256327875045759413123457324012204244904348160287525082997271790713457882660955619888946254261043203027771593298628441011612035265723835242026121235268765066944326490013942087806775580532770419185006727693836762421126549971166777350187227849036747874498748898200371278162103260529601535123784241275436339520934294087305771785057763906429748321306960060302877347805301757220204940169408640087558461307977499958542938818185362073916109749225361753465488257725527781630462231753011771059924172480693534542047579157001196799192378909460518139302358557373319671729492711810667118192183711386265644011686234954732739561715352966757275591394362051763747096082775428034331257483730208748244296931348278644467996131508327249311248703598496538092607531165259331139922697302096359403581744626882396938437309021732688016235359847356456980294356847006056239507114391778248012879303412205211396556204524145521662064393273536726990926093148343745926511722322805650194868790817814574744175510423873562280366546710025852968180416945163684882551407895812254630573660655532948916284348570078749620871743294686585436504822696481572626713064081970623249985910047616445949491493081152698162104745221931251546873892289
  localparam K_VALUE = 143470092535370572884762559577261597060726098095130651285005957313214286020208846248841066413839665875461265127305468068675031009431615257076642373897015244136524563555490527907489468206900169957371718405066201235672090362478853663742336475964379108870711218822319915578568841927832446909576170206724004148662014335256366686051416432871380265066096266104993996707561049975588005673291226873645650089976222132906287395873762164927828399409677542706610136520339776715033573328301612875290174288048957888104513170905651338622165968798603889655834913370256159826940403775407788986108836704031341025569895498152471030201955294429901239594071770739717406269774068252071820981877376647344316707332724263561803448778502843622405588443134412694906949791848247581439427186190448488327675794671096010372437761696016989799470309941546670264823723175030798254161797471206863652908093391507702691498503852245524787840057862796014700934951893477680960594052882015846665426104688827909670722048223991884739539367655706233535869616672961157302847254190896924514009866479293385406880250829014263662616828841246401389608022822438266332289468984960397434107372764152486555063086719771617731206415603770119148562143343177455545346632889001702426541456831
  localparam R_SQUARED_MOD_VALUE = 132653116745465813403613936559069372346722930557434473523067957962139174147639570382609150215473852099310862715418315754256629031708241253285733518596158476805300552566686726927504837278883965080495382848082573337043841241151347034236865433165934808314563917605348417149352559070105236793349333411165178494017193612029530135683590235832621117643483257960841382482566828200165362953933212744870778387316585010755252192618763852118666505509110164281703384305576820345618658907503898679265927003208874366061901691470558053463435436192414528970428955033584996196561304871511985926651623620243992602501042900959601353014009247857299811376737762601587607457265431823683991986277481408760830022712585041671185865548693828284420180131103255330375946415589002974503532392725125325802529472017204262336044459002093540427475819883705301022499935384321533809020567530017219788046878864094538881594440915158159245544658905846436155718922734239212607052645505401838339030536830621170763946507991183762344554251755406330052399252863137023291073940788178312530993643691268558867304945727174752519483342330983200789644685219568271101672657194302944828023930179397792108420415761819262383882241989842819883717036322935186066387339738662919582844814616
  // localparam LAMBDA_VALUE = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959964955464479024933422992909635397164311546361372532118006196725814332208510070121559031989216338031857983916010030668064205891373472234326096586015391335681399251733336672726683199532344809536988586555705039782732792395990414225992198743278061328019762865406265480992968614844386447881974648024301034133270890160
  // localparam MU_VALUE = 8915567752383628781438898187002797896548025900480737799095311841381836545755198503892372879726878495151035115946986868458012154448649583896132194358560329782831378798600255894543884351748301246095759638231762423081258773261447078148315461663411905258069603207263310818435311223030456445831047816378110749327580484779512120318259491191211823394214832953187276053506207701544252431583335833161276475407653180651152186091635887389297141653769732662414014629608293223179202238133723709179125878839638929208525481449388861597926415145013669009524453207751806355956198029749591583141643408193028947053783351959727470281524

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
  logic [$clog2(NUM_N_BLOCKS)-1:0][REGISTER_SIZE-1:0] n;
  logic [$clog2(NUM_G_BLOCKS)-1:0][REGISTER_SIZE-1:0] g; 
  logic [$clog2(NUM_N_SQUARED_BLOCKS)-1:0][REGISTER_SIZE-1:0] n_squared;
  logic [$clog2(NUM_R_SQUARED_BLOCKS)-1:0][REGISTER_SIZE-1:0] r_squared; 
  logic [$clog2(NUM_K_BLOCKS)-1:0][REGISTER_SIZE-1:0] k;
  
  localparam R_EXPONENT = N_SQUARED_SIZE; // = 4096
  always_ff @(posedge clk_100mhz) begin
    if (sys_rst) begin
      n <= N_VALUE;
      g <= G_VALUE;
      n_squared <= N_SQUARED_VALUE;
      r_squared <= R_SQUARED_MOD_VALUE;
      k <= K_VALUE;
    end
  end



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
    .rx_wire_in(), //TODO
    .new_data_out(valid_data),
    .data_byte_out(data_received_byte)
  );

  // For now we only send the candidate number
  // (Future: voterID)
  // (Future: more bytes for checking vote)

  // PROCESS VOTE
  logic candidate_vote;
  logic valid_processed_vote;

  vote_processor #(

  ) process_vote(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .valid_in(valid_data),
    //TODO
    .stall_in(),
    .new_byte_in(data_received_byte),
    .vote_out(candidate_vote),
    .voter_id_out(), //TODO later for stretch
    .valid_vote_out(valid_processed_vote)
  );

  // GENERATE RANDOM NUMBER
  logic [REGISTER_SIZE-1:0] random_block;
  logic random_valid;

  // generates a 4096 bit output in register size sizes, but the topmost 2048 bits are 0
  rand_gen#(
    .BITSIZE(REGISTER_SIZE)
  ) 
  rng_stream
  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .trigger_in(valid_processed_vote),
    .rand_out(random_block),
    .valid_out(random_valid)
  );

  // [Multiplier Block Select Counter]
  // R_SQUARED Block Select
  logic[$clog2(NUM_R_SQUARED_BLOCKS)-1:0] r_squared_select_index;   //! Convention: _select_index
  evt_counter #(.MAX_COUNT(NUM_R_SQUARED_BLOCKS))
  r_squared_block_select
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(random_valid),  
    .count_out(r_squared_select_index) // Notice this is initialized to 0, and there's a 1 cycle delay until next index.
  );
  logic[REGISTER_SIZE-1:0] r_squared_selected_block;              //! Convention: _selected_block
  assign r_squared_selected_block = r_squared[r_squared_select_index];

  // MULTIPLIER rand * r_squared_mod
  logic [REGISTER_SIZE-1:0] rand_RR_mult_out_block;
  logic rand_RR_mult_out_valid;
  fsm_multiplier  #(
    .register_size(REGISTER_SIZE),
    .bits_in_num(R_SQUARED_MOD_SIZE)
  )
  multplier_rand_RR
  (
    .n_in(random_block),
    .m_in(r_squared_selected_block),
    .valid_in(random_valid),
    .rst_in(sys_rst),
    .clk_in(clk_100mhz),
    .data_out(rand_RR_mult_out_block),
    .valid_out(rand_RR_mult_out_valid),
  );


  // [Montgomery Reduction Block Select Counters] 
  // N_SQUARED Block Select
  logic[$clog2(NUM_N_SQUARED_BLOCKS)-1:0] n_squared_select_index;
  logic consumed_n_squared_out; // triggers after reducing (TODO: initialize to 0)
  evt_counter #(.MAX_COUNT(NUM_N_SQUARED_BLOCKS))
  n_squared_block_select
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(consumed_n_squared_out),
    .count_out(n_squared_select_index)
  );
  logic[REGISTER_SIZE-1:0] n_squared_selected_block;
  assign n_squared_selected_block = n_squared[n_squared_select_index];

  
  // K Block Select
  logic[$clog2(NUM_K_BLOCKS)-1:0] k_select_index;
  logic consumed_k_out; // triggers after reducing (TODO: initialize to 0)
  evt_counter #(.MAX_COUNT(NUM_K_BLOCKS))
  k_block_select
  ( .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .evt_in(consumed_k_out),
    .count_out(k_select_index)
  );
  logic[REGISTER_SIZE-1:0] k_selected_block;
  assign k_selected_block = k[k_select_index];


  // MONTGOMERY REDUCE rand*R*R  (will get montgomery form of rand)
  logic [REGISTER_SIZE-1:0] reduced_product_block;
  logic placeholder_reduce_valid1;
  montgomery_reduce#(
    .register_size(REGISTER_SIZE),
    .num_blocks(NUM_T_BLOCKS),
  ) reducer1_stream(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .valid_in(placeholder1_mult_valid_out),
    .product_t_in(placeholder1_mult_out),
    .k_in(k_selected_block),
    .consumed_k_out(consumed_k_out),
    .n_squared_in(n_squared_selected_block),
    .consumed_n_squared_out(consumed_n_squared_out),
    .data_out(reduced_product_block),
    .valid_out(placeholder_reduce_valid1)
  );

  squarer_streamer#(
    .register_size(REGISTER_SIZE),
    .num_blocks(NUM_T_BLOCKS),
  )
  squarer_stream ( 
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .valid_in(placeholder_reduce_valid1),
    .initial_data_stream_in(reduced_product_block),

  )




    


    



endmodule // top_level


`default_ne

