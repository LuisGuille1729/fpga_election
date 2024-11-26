`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    input wire          clk_100mhz,
    input wire          [1:0] btn,
    output logic [15:0] led
  );

  logic   sys_rst;
  logic start;
  assign sys_rst = btn[0];
  assign start = btn[1];

  logic [31:0] rega;
  logic [31:0] regb;
  logic [31:0] regc;
  always_ff @( posedge clk_100mhz ) begin 
    rega <= rega +1;
    regb <= regb +2;
    regc <= regc +3;
  end

  logic [31:0] result;
  logic valid_out;
  logic consumedk;
  logic consumedN;

  montgomery_reduce  #(
    .REGISTER_SIZE(32),
    .NUM_BLOCKS(256),
    .R(4096)
    )
  test_reduce_compiling
  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),

    .valid_in(start),
    .T_block_in(rega),

    .k_constant_block_in(regb),
    .consumed_k_out(consumedk),

    .modN_constant_block_in(regc),
    .consumed_N_out(consumedN),

    .valid_out(valid_out),
    .data_block_out(result)
  );

    always_ff @( posedge clk_100mhz ) begin 
      if (sys_rst)
        led <= 0;
      else
        led <= valid_out ? result : led;
    end


// TODO Fill in the Encryptor stuff post montgomery exponentiation
// at this point we can test if encryption works for 1 candidate









    


    



endmodule // top_level


`default_nettype wire

