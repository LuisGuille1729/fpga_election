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

  // (Future: voterID)
  // (Future: more bytes for checking vote)

logic candidate_vote;
logic valid_vote_out;

vote_processor #(

) process_vote(
  .clk_in(clk_100mhz),
  .rst_in(sys_rst),
  .valid_in(valid_data),
  .new_byte_in(data_received_byte),
  .vote_out(candidate_vote),
  .valid_vote_out(valid_vote_out)
);

logic [31:0] random_block;
logic random_valid;

rand_gen#(
  .BITSIZE(32)
) 
rng
(
  .clk_in(clk_100mhz),
  .rst_in(sys_rst),
  .rand_out(random_block),
  .valid_out(random_valid)
);



endmodule // top_level


`default_ne

