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
  logic [10:0] index;
  logic [31:0] r_squared;
  always_ff @( posedge clk_100mhz ) begin 
    if (sys_rst) begin
      index <= 0;
      rega <= 0;
      regb <= 0;
      regc <= 0;
      r_squared <= 32'hdead_beaf;
    end
    index <= index + 1; 
    rega <= r_squared[31:0];
    r_squared <= r_squared>>1 | start;
    regb <= regb +2 + start;
    regc <= regc +3 + start;
  end

  logic [31:0] result;
  logic valid_out;
  logic consumedk;
  logic consumedN;

  logic extra1;
  logic extra2;
  logic extra3;
  logic extra4;
  logic final_out;

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
    .data_block_out(result),
    .final_out(final_out),

    .extra1(extra1),
    .extra2(extra2),
    .extra3(extra3),
    .extra4(extra4)
  );

    always_ff @( posedge clk_100mhz ) begin 
      if (sys_rst)
        led <= 0;
      else
        led[14:0] <= valid_out ? result : led[14:0];
        led[15] <= extra1 | extra2 | final_out | extra3 | extra4;
    end


// TODO Fill in the Encryptor stuff post montgomery exponentiation
// at this point we can test if encryption works for 1 candidate









    


    



endmodule // top_level


`default_nettype wire

