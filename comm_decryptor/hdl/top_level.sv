`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    input wire          clk_100mhz,
    input wire          [2:0] btn,
    
    input wire [15:0] sw,

    input wire uart_rxd, // UART computer-FPGA


    output logic [2:0] rgb0, // RGB channels of RGB LED0
    output logic [2:0] rgb1, // RGB channels of RGB LED1
    output logic [15:0] led,

    output logic uart_txd,

    input wire cipo,
    output logic dclk,
    output logic copi,
    output logic cs
  );

  localparam BAUD_RATE = 9600;

  logic   sys_rst;
  assign sys_rst = btn[0];
  logic start;
  assign start = btn[1];

  // assign led = sw;

  logic previous_start;
  logic trigger_uart_send;
  always_ff @(posedge clk_100mhz) begin
    previous_start <= start;
    trigger_uart_send <= start & !previous_start;
  end


  // UART Transmitter 
  
  logic uart_busy;

  uart_transmit #(.BAUD_RATE(BAUD_RATE)) 
  fpga_to_pc_uart  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .data_byte_in(sw[7:0]),
    .trigger_in(trigger_uart_send),
    .busy_out(uart_busy),
    .tx_wire_out(uart_txd)
  );





  

endmodule // top_level


`default_nettype wire

