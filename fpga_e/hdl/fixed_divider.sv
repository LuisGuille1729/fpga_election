`default_nettype none

// Fixed integer divisor of x // n where
// n is our 2048-bits pq, and x is an arbitrary 4096-bit number, i.e. n = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767
// Requires the mult_inv constant, must be correctly signalled in top level
// mult_inv = 75299540386319832354160211189449715021739337572771619406034950168942320910896840776854970153328317531817236329179406815725689583186853726176905598397390492914804344618125333378787729278321822183396226413688586713590845583585245299283933344483047261329067452218606922201317313088493682065927111964296840109381400532732683401088837160650764546687277777040847177422585670354027880681475100346339193036529984948819170330947279644998579025953595192781811896396668196204841894496431652498822227328376699452763141358399571873467329760181720536465116539495136425372850124300208989594033363546950075573838411453104518901916641298228905697185061669962474356751283187733596877822574754600206684623527575365198056857919390629210755372526149688690285459057377006634195232860727511107656767724680749521238380812355199943718493222164182270400520542015300202052832180915193602335560545451968421551161541355504581254594258915106723392088252063735102087361162514814839309376422247892492224101277591803585351248659373063887685892589143245270972989148291111483798381921903845592141897141997014415163682658432361342924395636546114735726870516464138489520449436370149940037433753071794727253607057736971930561852387076048984088400948076

// Note: to use for some other n, must change mult_inv (see divider4096_demo.py)

module fixed_divider #(
    parameter REGISTER_SIZE = 32,
    parameter NUM_BLOCKS_IN = 128,
    parameter BITS_EXPONENT = 6080, // only change if changing divider n
    parameter NUM_BLOCKS_OUT = 64
)(
    input wire clk_in,
    input wire rst_in,

    input wire valid_in,
    input wire [REGISTER_SIZE-1:0] x_block_in,   // the number we want to divide by
    
    input wire [REGISTER_SIZE-1:0] mult_inv_constant_block_in, // we implement in top level so that it is paired at the same time with the corresponding x_block_in. In future, can implement this directly.

    output logic valid_out,
    output logic [REGISTER_SIZE-1:0] data_block_out
);
// Outputs (x * mult_inv) >> BITS_EXPONENT, which is equivalent to x // n
// Main source: https://rubenvannieuwpoort.nl/posts/division-by-constant-unsigned-integers 
localparam BITS_IN_NUM = REGISTER_SIZE * NUM_BLOCKS_IN;
localparam BLOCKS_TO_IGNORE = BITS_EXPONENT / REGISTER_SIZE;

logic [REGISTER_SIZE-1:0] x_times_mult_inv_block;
logic x_times_mult_inv_valid;
logic mult_force_rst;
fsm_multiplier #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(BITS_IN_NUM)
)
x_times_mult_inv
(
    .n_in(x_block_in),
    .m_in(mult_inv_constant_block_in),
    .valid_in(valid_in),

    .rst_in(rst_in || mult_force_rst),
    .clk_in(clk_in),

    .data_out(x_times_mult_inv_block),
    .valid_out(x_times_mult_inv_valid)
); // 256 blocks (8192 bits output) (though the top part will be 0)


// (x * mult_inv) >> BITS_EXPONENT, only output NUM_BLOCKS_OUT of these

// Now output only the first NUM_BLOCKS_OUT after >> BITS_EXPONENT
// (the blocks ignored will be all zeros anyways)
logic [$clog2(BLOCKS_TO_IGNORE):0] blocks_to_ignore;
logic [$clog2(NUM_BLOCKS_OUT+BLOCKS_TO_IGNORE):0] blocks_to_output;

always_ff @( posedge clk_in ) begin
    if (rst_in || !x_times_mult_inv_valid) begin
        blocks_to_ignore <= BLOCKS_TO_IGNORE;
        blocks_to_output <= NUM_BLOCKS_OUT + BLOCKS_TO_IGNORE;
        mult_force_rst <= 1'b0;
    // end else if (x_times_mult_inv_valid) begin
    end else begin
        blocks_to_ignore <= (blocks_to_ignore == 0) ? 0 : blocks_to_ignore - 1;
        blocks_to_output <= (blocks_to_output == 0) ? 0 : blocks_to_output - 1;
        if (blocks_to_output == 0)
            mult_force_rst <= 1'b1;
    end
end

// Pipe the result so that multiplier can clean itself before next valid in
logic valid_out_pipe1;
logic [REGISTER_SIZE-1:0] data_block_out_pipe1;
always_ff @(posedge clk_in ) begin
    data_block_out_pipe1 <= x_times_mult_inv_block;
    valid_out_pipe1 <= (blocks_to_ignore == 0) && (blocks_to_output != 0);
    data_block_out <= data_block_out_pipe1;
    valid_out <= valid_out_pipe1;
end

// In reality, we likely don't really care about this (can assume valid_in will be far enough), so can just do this
// assign data_block_out_pipe1 <= x_times_mult_inv_block;
// assign valid_out_pipe1 <= (blocks_to_ignore == 0) && (blocks_to_output != 0);



endmodule





// (ORIGINAL IDEA - DISCARDED)

// Long division algorithm
// 1. Bit-align the left-most “1” of the divisor with the left-most “1” of the dividend
// 2. Set all quotient bits to “0”
// 3. If the dividend ≥ divisor
//      - Set the quotient bit that corresponds to the position of the divisor to “1”
//      - Subtract the divisor from the dividend
// 4. Shift the divisor 1 bit to the right
// 5. If the leading bit of the divisor is at a position ≥ 0, return to step 3
// 6. Otherwise we’re done

// Returns the comparison result of up the first NUM_BLOCKS blocks,
// With one cycle delay to receive output of result
// module running_divider #(
//     parameter REGISTER_SIZE = 32,
//     parameter NUM_BLOCKS_IN = 128
// )(
//     input wire clk_in,
//     input wire rst_in,

//     input wire valid_in,
//     input wire [REGISTER_SIZE-1:0] a_block_in,

//     input wire [REGISTER_SIZE-1:0] n_block_in,
//     output wire consumed_n_out,
    
//     output logic valid_out,
//     output logic [REGISTER_SIZE-1:0] r_data_block_out,
//     output logic [REGISTER_SIZE-1:0] q_data_block_out
// );
//     localparam NUM_BLOCKS_OUT = NUM_BLOCKS_IN/2;
//     localparam BITS_IN_NUM_IN = REGISTER_SIZE*NUM_BLOCKS_IN;
//     localparam BITS_IN_NUM_OUT = BITS_IN_NUM_IN/2;

//     enum bit [1:0] {IDLE, COMPARATING, UPDATING, OUTPUTING} state;



//     smart_bram_block_combinator #(
        
//     ) bram_a_cache (
//         .rst_in(),
//         .force_write_valid_in(),
//         .force_write_block_in(),
        
//         .index_in(),
//         .activate_index_read_in(),
//         .index_read_block_out(),

//         .index_write_valid(),
//         .index_write_block_in()
//     );


//     running_comparator #(

//     ) compare_a_with_n (

//     )

//     great_subtractor # (

//     ) subtract_a_minus_n (

//     )


//     smart_bram_block_single_bit_setter # (

//     ) bram_q_result (
        
//     )



//     always_comb begin
       
//     end

//     always_ff @( posedge clk_in ) begin
//         if (rst_in || block_count == NUM_BLOCKS-1) begin
//             state <= IDLE;
//             block_count <= 0;
//         end else if (valid_in) begin 
//             // state <= comparison_result_out; // update state. Need to do in case statement because verilog is annoying
//             case (comparison_result_out)
//             IDLE: 
//                 state <= IDLE;
//             A_LESS_THAN_B:
//                 state <= A_LESS_THAN_B;
//             A_EQUAL_B:
//                 state <= A_EQUAL_B;
//             A_GREATER_THAN_B:
//                 state <= A_GREATER_THAN_B;
//             endcase
//             block_count <= block_count + 1;
//         end

//     end

// endmodule

`default_nettype wire