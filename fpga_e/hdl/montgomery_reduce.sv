`default_nettype none

module montgomery_reduce #(
    parameter REGISTER_SIZE = 32,
    parameter NUM_BLOCKS = 256,
    parameter R = 4096
) (
    input wire clk_in,
    input wire rst_in,

    input wire valid_in,
    input wire [REGISTER_SIZE-1:0] T_block_in,   // the number we want to reduce by
    
    input wire [REGISTER_SIZE-1:0] k_constant_block_in, 
    output logic consumed_k_out,
    
    input wire [REGISTER_SIZE-1:0] modN_constant_block_in,
    output logic consumed_N_out,

    output valid_out,
    output data_block_out,
)
// Efficiently calculates T(R^-1) mod N
// For most use cases, modN_constant_block_in will be our n_squared

localparam T_TOTAL_SIZE = REGISTER_SIZE*NUM_BLOCKS;
localparam CONSTANT_SIZE = R


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
    .write_block_in(T_block_in)

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
)


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
)

always_ff @( posedge clk_in ) begin
    if (!sys_rst)
        consumed_k_out <= T_modR_valid; // request next k block for the multiplier
end

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
    .block_in(Tk_product_valid),

    .valid_out(product_Tk_modR_valid),
    .data_block_out(product_Tk_modR_block)
)

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
)
always_ff @( posedge clk_in ) begin
    if (!sys_rst)
        consumed_N_out <= product_Tk_modR_valid; // request next N block for the multiplier
end

// Adder T + mN
logic addition_T_mN_valid;
logic [REGISTER_SIZE-1:0] addition_T_mN_block;
logic addition_T_mN_block_carry;
logic addition_T_mN_done;

great_adder #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(T_TOTAL_SIZE)  // 8192
)
adder_T_plus_mN
(
    .a_in(product_Mn_block),
    .b_in(read_T_block_value),  // from BRAM
    .carry_in(1'b0),
    
    .valid_in(product_Mn_valid),

    .rst_in(rst_in),
    .clk_in(clk_in),

    .data_out(addition_T_mN_block),
    .carry_out(addition_T_mN_block_carry), // The carry will be needed to determine if t < N or not !!!
    .valid_out(addition_T_mN_valid),
    .final_out(addition_T_mN_done)
)


always_ff @(posedge clk_in) begin
    if (!rst_in) begin
        read_next_T_block_valid <= product_Mn_valid; // Request next T block for adder 
        // Will update product_Mn_valid after two cycles.
        // (there's a two cycle delay, but should be fast enough compared to the multiplier)
        // (if not, then look into pipelining it)
    end
end

logic final_carry;
assign final_carry = (addition_T_mN_done) ? addition_T_mN_block_carry : final_carry;


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

    .valid_in(addition_T_mN_valid),
    .block_in(addition_T_mN_block),
    
    .valid_out(rshift_T_mN_byR_valid),
    .data_block_out(rshift_T_mN_byR_block)
);

//rename
logic t_block_valid;
assign t_block_valid = rshift_T_mN_byR_valid;
logic [REGISTER_SIZE-1:0] t_block_value;
assign t_block_value = rshift_T_mN_byR_block;

// Need to determine if t < N

// Idea:
// new module for comparison,
// will compare incoming blocks to until end, so it can determine if bigger or smaller (remember to take into account the carry of adder_T_plus_mN)
// will need to save bram the values of t
// if t < N, then just output the values of the t_bram
// if t >= N, then output the addition of N + ~t with carry_in 1 (note: even if carry of adder_T_plus_mN is 1, the complement would make it 0)
// we would likely want an module to make this subtraction easier.
// sadly needing to get this comparison will delay us by NUM_BLOCKS=256 cycles
// maybe there's a workaround? 

endmodule

`default_ne