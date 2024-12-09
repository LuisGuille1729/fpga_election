`default_nettype none
module vote_processor  (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,
    input wire [7:0] new_byte_in,
    input wire request_new_vote,
    output logic vote_out,
    output logic valid_vote_out
  );

  logic[4:0] sum_ones = new_byte_in[0] + new_byte_in[1] + new_byte_in[2] +  new_byte_in[3] 
                 + new_byte_in[4] +  new_byte_in[5] + new_byte_in[6] + new_byte_in[7];
  logic new_vote;
  assign new_vote = sum_ones>4;

  localparam MAX_VOTES = 10000;

  localparam VOTE_SIZE = 1;
  localparam NUM_VOTE_BLOCKS = MAX_VOTES/VOTE_SIZE; 
  logic[$clog2(MAX_VOTES)-1:0] read_counter;
  logic[$clog2(MAX_VOTES)-1:0] write_counter;

  evt_counter #(.MAX_COUNT(MAX_VOTES))
  read_counter_inst
  ( 
    .clk_in(clk_in),
    .rst_in(rst_in),
    .evt_in(request_new_vote),
    .count_out(read_counter)
  );

  evt_counter #(.MAX_COUNT(MAX_VOTES))
  write_counter_inst
  ( 
    .clk_in(clk_in),
    .rst_in(rst_in),
    .evt_in(valid_in),
    .count_out(write_counter)
  );

  logic read_possible;
  assign read_possible = read_counter != write_counter;
  bram_blocks_rw #(
    .REGISTER_SIZE(1),
    .NUM_BLOCKS(NUM_VOTE_BLOCKS)
  ) block_module (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .read_next_block_valid_in(read_possible&&request_new_vote), 
    .read_block_out(vote_out),
    .read_block_pipe2_valid_out(valid_vote_out),
    .read_done_all_blocks_pipe2_out(), // pipelined as well
    .read_requested_for_last_block(), // unpiped
    
    .write_next_block_valid_in(valid_in),
    .write_block_in(new_vote)
);

endmodule
`default_nettype wire