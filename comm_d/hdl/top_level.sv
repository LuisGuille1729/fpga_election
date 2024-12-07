`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
    input wire          clk_100mhz,
    input wire          [1:0] btn,
    
    input wire uart_rxd, // UART computer-FPGA
    output logic [2:0] rgb0, // RGB channels of RGB LED0
    output logic [2:0] rgb1, // RGB channels of RGB LED1
    output logic [15:0] led
  );

  localparam BAUD_RATE = 9600;

  logic   sys_rst;
  assign sys_rst = btn[0];
  logic start;
  assign start = btn[1];

  // UART Receive
  // We are assuming we are receiving the bits in lsb first order
  logic valid_data;
  logic [7:0] data_received_byte;
 
  logic uart_rx_buf0, uart_rx_buf1;  // buffers to prevent metastability
   always_ff @(posedge clk_100mhz) begin
    uart_rx_buf1 <= uart_rxd;
    uart_rx_buf0 <= uart_rx_buf1;
   end

  uart_receive #(
    .INPUT_CLOCK_FREQ(100_000_000),
    .BAUD_RATE(BAUD_RATE)
  ) laptop_encryptor_uart
  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .rx_wire_in(uart_rx_buf0), 
    .new_data_out(valid_data),
    .data_byte_out(data_received_byte)
  );

  always_ff @(posedge clk_100mhz) begin
    
    if (sys_rst) begin
      rgb0 <= 0;
      rgb1 <= 0;
      led <= 0;
    end
    else if (valid_data) begin
      rgb0[0] <= &(~data_received_byte);
      rgb0[1] <= &data_received_byte;
      rgb0[2] <= !(&(~data_received_byte) || &data_received_byte);

      rgb1 = 3'b111;

      led <= data_received_byte;
    end
    

  end


  

endmodule // top_level


`default_nettype wire

