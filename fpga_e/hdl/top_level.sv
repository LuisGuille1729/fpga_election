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

  logic [31:0] regu;
  logic [31:0] rega;
  always_ff @( posedge clk_100mhz ) begin 
    regu<=regu +1;
    rega <= rega +3;
  end

  logic [31:0] result;
  logic valid_out;

  fsm_multiplier  #(
    .REGISTER_SIZE(32),
    .BITS_IN_NUM(2048)
    )
    test_muller
    (
        .n_in(regu),
        .m_in(rega),
        .valid_in(1),
        .rst_in(sys_rst),
        .clk_in(clk_100mhz),
        .data_out(result),
        .valid_out(valid_out),
        .final_out(),
        .ready_out()
    );

    always_ff @( posedge clk_100mhz ) begin 
      led <= valid_out? result: led;
    end


// TODO Fill in the Encryptor stuff post montgomery exponentiation
// at this point we can test if encryption works for 1 candidate









    


    



endmodule // top_level


`default_nettype wire

