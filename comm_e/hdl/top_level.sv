`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    input wire          clk_100mhz,
    input wire          [1:0] btn
  );

  logic   sys_rst;
  assign sys_rst = btn[0];
  logic start;
  assign start = btn[1];

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

endmodule // top_level


`default_ne

