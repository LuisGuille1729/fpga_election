`default_nettype none
// computes addition of 2 numbers by writting to block ram and sending the data back out in cycles
// has a valid out signal and a last signal to showcase a finished addition. 
module candidate_encryptor  #(
    parameter REGISTER_SIZE = 32,
    parameter BITS_IN_NUM = 4096,
    parameter R  = 4096
) (
    input wire clk_in,
    input wire rst_in,
    input wire [REGISTER_SIZE-1:0] n_squared_in,
    input wire [REGISTER_SIZE-1:0] k_in,
    input wire [REGISTER_SIZE-1:0] exponentiator_in,
    input wire valid_in,
    input wire candidate_in,
    output logic consumed_k_out,
    output logic consumed_n_squared_out,
    output logic consumed_vote_out,  
    output logic valid_out,
    output logic[REGISTER_SIZE-1:0] data_out

);

logic [REGISTER_SIZE-1:0] candidate_casted_out;
logic candidate_casted_valid;

logic was_vaid;

logic long_valid;

always_comb begin
   long_valid = candidate_in && valid_in;
   data_out = candidate_in? true_casted_data: exponentiator_in;
   valid_out = casted_valid || (valid_in && (~candidate_in));
   consumed_candidate_out =  was_vaid && (!valid_out);
end


always_ff @( posedge clk_in ) begin
    if(rst_in)begin
        was_vaid<=0;
    end else begin
        was_vaid<= valid_out;
    end

    
end



candidate_multiplier  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(BITS_IN_NUM)
    )
    vote_1_caster
    (
        .n_in(exponentiator_in),
        .valid_in(long_valid),
        .rst_in(rst_in),
        .clk_in(clk_in),
        .data_out(candidate_casted_out),
        .valid_out(candidate_casted_valid),
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
 ) vote_1_reducer (
    .clk_in(clk_in),
    .rst_in(rst_in),

    .valid_in(candidate_casted_valid),
    .T_block_in(candidate_casted_out),   // the number we want to reduce
    
    .k_constant_block_in(k_in), // we implement in top level so k_constant_block_in is initialized to the first block and increments when consumed_k is set to 1
    .consumed_k_out(consumed_k_out),
    
    .modN_constant_block_in(n_squared_in),
    .consumed_N_out(consumed_n_squared_out),

    .valid_out(casted_valid),
    .data_block_out(true_casted_data),
    .final_out()
);







   

endmodule

`default_nettype wire
