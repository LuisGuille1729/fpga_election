`default_nettype none

// Efficiently calculates T(R^-1) mod N
// NOTE: k_constant_block_in and modN_constant_block_in MUST behave as expected in top level:
// Must be initialized to first block whenever valid_in is 1
// Every time a consumed signal is outputted, in the NEXT cycle give the next block
module montgomery_reduce #(
    parameter REGISTER_SIZE = 32,
    parameter NUM_BLOCKS = 256,
    parameter R = 4096
) (
    input wire clk_in,
    input wire rst_in,

    input wire valid_in,
    input wire [REGISTER_SIZE-1:0] T_block_in,   // the number we want to reduce
    
    input wire [REGISTER_SIZE-1:0] k_constant_block_in, // we implement in top level so k_constant_block_in is initialized to the first block and increments when consumed_k is set to 1
    output logic consumed_k_out,
    
    input wire [REGISTER_SIZE-1:0] modN_constant_block_in,
    output logic consumed_N_out,

    output logic valid_out,
    output logic [REGISTER_SIZE-1:0] data_block_out,
    output logic final_out
);
// For most use cases, modN_constant_block_in will be our n_squared

localparam T_TOTAL_SIZE = REGISTER_SIZE*NUM_BLOCKS;
localparam CONSTANT_SIZE = R;
localparam NUM_BLOCKS_OUTPUT = NUM_BLOCKS/2;


// Store T for later use in adder (T + mN)
logic read_next_T_block_valid;
logic [REGISTER_SIZE-1:0] read_T_block_value;
logic read_T_block_value_valid;

bram_blocks_rw #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS(NUM_BLOCKS)
) 
T_blocks_BRAM
(
    .clk_in(clk_in),
    .rst_in(rst_in),

    // Write T !!!
    .write_next_block_valid_in(valid_in),   
    .write_block_in(T_block_in),

    // Read T (needed for later)
    .read_next_block_valid_in(read_next_T_block_valid), 
    .read_block_out(read_T_block_value),
    .read_block_pipe2_valid_out(read_T_block_value_valid)
);

//*** calculate m :=  (T%R)*k %R ***//

// T mod R
logic T_modR_valid;
logic [REGISTER_SIZE-1:0] T_modR_block;
modulo_of_power #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS(NUM_BLOCKS),
    .MODULO(R)
)
    T_modR_modulo
(
    .clk_in(clk_in),
    .rst_in(rst_in),

    .valid_in(valid_in),
    .block_in(T_block_in),

    .valid_out(T_modR_valid),
    .data_block_out(T_modR_block)
);


// Multiplier: T%R * k
logic [REGISTER_SIZE-1:0] Tk_product_block_value;
logic Tk_product_valid;
fsm_multiplier #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(CONSTANT_SIZE)
)
multiplier_TmodR_times_k
(
    .n_in(k_constant_block_in),
    .m_in(T_modR_block),
    .valid_in(T_modR_valid),

    .rst_in(rst_in),
    .clk_in(clk_in),

    .data_out(Tk_product_block_value),
    .valid_out(Tk_product_valid)
);

// always_ff @( posedge clk_in ) begin
//     if (rst_in)
//         consumed_k_out <= 0;
//     else
//         consumed_k_out <= T_modR_valid; // request next k block for the multiplier
// end
assign consumed_k_out = T_modR_valid; // Must be combinational!

// Tk mod R     (result will be m := (T%R)k %R)
logic product_Tk_modR_valid;
logic [REGISTER_SIZE-1:0] product_Tk_modR_block;
modulo_of_power #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS(NUM_BLOCKS),
    .MODULO(R)
)
    product_Tk_modR_modulo
(
    .clk_in(clk_in),
    .rst_in(rst_in),

    .valid_in(Tk_product_valid),
    .block_in(Tk_product_block_value),

    .valid_out(product_Tk_modR_valid),
    .data_block_out(product_Tk_modR_block)
);

//*** calculate t :=  (T+mN)/R ***//

// Multiplier m * N
logic product_Mn_valid;
logic [REGISTER_SIZE-1:0] product_Mn_block;
fsm_multiplier #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(CONSTANT_SIZE)
)
multiplier_m_times_N
(
    .n_in(modN_constant_block_in),
    .m_in(product_Tk_modR_block),
    .valid_in(product_Tk_modR_valid),

    .rst_in(rst_in),
    .clk_in(clk_in),

    .data_out(product_Mn_block),
    .valid_out(product_Mn_valid)
);

// (The following is assigned in the always_ff after the comparator)
//         // request next N block for the MULTIPLIER
//         // or for the COMPARATOR
//         consumed_N_out <= product_Tk_modR_valid || t_result_block_valid; 


// Adder T + mN
logic addition_T_mN_result_valid;
logic [REGISTER_SIZE-1:0] addition_T_mN_block;
logic addition_T_mN_block_carry;
logic addition_T_mN_done;

// Need to pipeline in order to correspond to the T output from BRAM
logic [REGISTER_SIZE-1:0] product_Mn_block_piped;
pipeliner #(
    .PIPELINE_STAGE_COUNT(2),
    .DATA_BIT_SIZE(REGISTER_SIZE)
)
product_Mn_block_pipeline
(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .data_in(product_Mn_block),
    .data_out(product_Mn_block_piped)
);

logic  product_Mn_valid_piped;
pipeliner #(
    .PIPELINE_STAGE_COUNT(2),
    .DATA_BIT_SIZE(1)
)
product_Mn_valid_pipeline
(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .data_in(product_Mn_valid),
    .data_out(product_Mn_valid_piped)
);


great_adder #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(T_TOTAL_SIZE)  // 8192
)
adder_T_plus_mN
(
    .a_in(product_Mn_block_piped), // need to be pipelined by 2 cycles!!!
    .b_in(read_T_block_value),  // from BRAM
    .carry_in(1'b0),
    
    .valid_in(product_Mn_valid_piped), // need to be pipelined by 2 cycles!!!

    .rst_in(rst_in),
    .clk_in(clk_in),

    .data_out(addition_T_mN_block),
    .carry_out(addition_T_mN_block_carry), // The carry will be needed to determine if t < N or not !!!
    .valid_out(addition_T_mN_result_valid),
    .final_out(addition_T_mN_done)
);


// always_ff @(posedge clk_in) begin
//     if (rst_in) 
//         read_next_T_block_valid <= 0;
//     else
//         read_next_T_block_valid <= product_Mn_valid; // Request next T block for adder 
//         // Will update product_Mn_valid after two cycles.
//         // (there's a two cycle delay, but should be fast enough compared to the multiplier)
//         // (if not, then look into pipelining it)
// end
assign read_next_T_block_valid = product_Mn_valid;

logic final_carry;
// (The following is assigned in the always_ff after the comparator)
// final_carry <= (addition_T_mN_done) ? addition_T_mN_block_carry : final_carry;
// Update: that ^^^ is actually a bug, since addition_T_mN_done occurs simulatneously with comparison_done
// instead just do:
assign final_carry = addition_T_mN_block_carry;

// Right Shift T+mN by R    (result will be t := (T + mN)>>R )
logic rshift_T_mN_byR_valid;
logic [REGISTER_SIZE-1:0] rshift_T_mN_byR_block;
right_shifter #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS(NUM_BLOCKS),
    .SHIFT_BY(R)
)
rshift_T_mN_byR
(
    .clk_in(clk_in),
    .rst_in(rst_in),

    .valid_in(addition_T_mN_result_valid),
    .block_in(addition_T_mN_block),
    
    .valid_out(rshift_T_mN_byR_valid),
    .data_block_out(rshift_T_mN_byR_block)
);

//rename
logic t_result_block_valid;
assign t_result_block_valid = rshift_T_mN_byR_valid;
logic [REGISTER_SIZE-1:0] t_result_block_value;
assign t_result_block_value = rshift_T_mN_byR_block;

//*** Now output (t < N) ? t : t-N (this output will be equivalent to T%N) ***//

// Idea:
// new module for comparison,
// will compare incoming blocks to until end, so it can determine if bigger or smaller (remember to take into account the carry of adder_T_plus_mN)
// will need to save bram the values of t
// if t < N, then just output the values of the t_bram
// if t >= N, then output the addition of N + ~t with carry_in 1 (note: even if carry of adder_T_plus_mN is 1, the complement would make it 0)
// we would likely want an module to make this subtraction easier.
// sadly needing to get this comparison will delay us by NUM_BLOCKS=256 cycles
// maybe there's a workaround? 


// Store the results of rshift_T_mN_byR
// Will be needed for output once the comparison is determined.
// NOTE FOR FUTURE: Can optimize by reusing the T_blocks_BRAM for this purpose.
// If done so, be careful that it does not break anything with top-level due to timing (it shouldn't)
logic read_next_t_result_block_valid;
logic [REGISTER_SIZE-1:0] read_t_result_block_value;
logic read_t_result_block_value_valid;
logic all_t_blocks_read;

bram_blocks_rw #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS(NUM_BLOCKS_OUTPUT) // i.e. 4096 bits
) 
t_result_blocks_BRAM
(
    .clk_in(clk_in),
    .rst_in(rst_in),

    // WRITE t_result
    .write_next_block_valid_in(t_result_block_valid),   
    .write_block_in(t_result_block_value),

    // READ t_result
    .read_next_block_valid_in(read_next_t_result_block_valid), 
    .read_block_out(read_t_result_block_value),
    .read_block_pipe2_valid_out(read_t_result_block_value_valid),
    .read_done_all_blocks_pipe2_out(),
    .read_requested_for_last_block(all_t_blocks_read)
);

// Compare t < N

logic comparison_done;
logic [1:0] comparison_result; 
    // comparison_result is:
    // 00 - NULL
    // 01 - A less than B
    // 10 - A greater than B
    // 11 - A equals B

running_comparator #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS(NUM_BLOCKS_OUTPUT)   // 4096 bits comparison
)
compare_t_with_N (
    .clk_in(clk_in),
    .rst_in(rst_in),

    .valid_in(t_result_block_valid),
    .block_numA_in(t_result_block_value),  

    .block_numB_in(modN_constant_block_in),

    .comparison_result_out(comparison_result),
    .end_comparison_signal_out(comparison_done) //(this is always a single cycle signal)
);

logic dispatch_output;
logic is_t_less_than_N; // used to determine which to output (t or t-N)

assign consumed_N_out = product_Tk_modR_valid || t_result_block_valid || read_t_result_block_value_valid; 

always_ff @( posedge clk_in ) begin
    if (rst_in) begin
        // consumed_N_out <= 0;
        valid_out <= 0;
        // final_carry <= 0;
        dispatch_output <= 0;
        is_t_less_than_N <= 0;
        data_block_out <= 0;
    end else begin
        // request next N block for the MULTIPLIER
        // OR for the COMPARATOR
        // OR for the t-N SUBTRACTION
        // consumed_N_out <= product_Tk_modR_valid || t_result_block_valid || read_t_result_block_value_valid; 

        // Recall the final carry from the addition, will be needed to determine true comparison.
        // final_carry <= (addition_T_mN_done) ? addition_T_mN_block_carry : final_carry;
        // However, addition_T_mN_done and comparison_done occur simultaneously! This breaks a cycle
        // Instead just use addition_T_mN_block_carry.

        // Determine whether to output t or t-N
        if (comparison_done) begin
            dispatch_output <= 1;
            // note if final_carry is 1, then immediately t > N
            if (!final_carry && comparison_result == 2'b01) // t < N
                is_t_less_than_N <= 1;
            else 
                is_t_less_than_N <= 0;

        end
        else if (all_t_blocks_read) begin
            dispatch_output <= 0;   // stop outputting t_result blocks
        end

        if (read_t_result_block_value_valid) begin
            
            valid_out <= 1;
            if (is_t_less_than_N) begin

                data_block_out <= read_t_result_block_value;

            end else begin // t >= N, so output t - N instead

                data_block_out <= t_minus_N_block_result;

            end


        end else begin
            valid_out <= 0;

        end

    end
end

assign final_out = valid_out & !read_t_result_block_value_valid; 

assign read_next_t_result_block_valid = dispatch_output; // will start outputting the t_result blocks into read_t_result_block_value every cycle

logic [REGISTER_SIZE-1:0] t_minus_N_block_result;
// Calculate t-N:
great_subtractor #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(NUM_BLOCKS_OUTPUT*REGISTER_SIZE)
)
subtract_t_minus_N
(
    .a_in(read_t_result_block_value),
    .b_in(modN_constant_block_in),
    .valid_in(read_t_result_block_value_valid),

    .rst_in(rst_in),
    .clk_in(clk_in),

    .data_out(t_minus_N_block_result),
    .valid_out(),
    .final_out()
);





endmodule

`default_nettype wire