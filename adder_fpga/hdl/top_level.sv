`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
   input wire          clk_100mhz,
   input wire          [1:0] btn
   );

  logic   sys_rst;
  assign sys_rst = btn[0];
  assign start_sum = btn[1];

  // NOTE: How to optimize?
  // Maybe test different sizes of widths etc

  // 8-bit addresses for 4 2048 bit-numbers (8192 total bits in 32 bit chunks)
  // obviously we should modify the sizes as needed
  logic [7:0] bram_write_addr;
  logic [7:0] bram_read_addr;

  logic [31:0] write_data;
  logic [31:0] read_data;

  xilinx_true_dual_port_read_first_1_clock_ram
  #(
    .RAM_WIDTH(32), // 32*64 = 2048
    .RAM_DEPTH(256), // 4 2048-bit numbers = 256 32-bit numbers --> 8 bit addresses
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
    .INIT_FILE("adder_demo.mem")
  ) addition_registers
  ( // A - write port     B - read port
      .addra(bram_write_addr),  // Port A address bus, width determined from RAM_DEPTH
      .addrb(bram_read_addr),  // Port B address bus, width determined from RAM_DEPTH
      .dina(write_data),           // Port A RAM input data
      .dinb(),           // Port B RAM input data
      .clka(clk_100mhz),                           // Clock
      .wea(1'b1),                            // Port A write enable
      .web(1'b0),                            // Port B write enable
      .ena(1'b1),                            // Port A RAM Enable, for additional power savings, disable port when not in use
      .enb(1'b1),                            // Port B RAM Enable, for additional power savings, disable port when not in use
      .rsta(sys_rst),                           // Port A output reset (does not affect memory contents)
      .rstb(sys_rst),                           // Port B output reset (does not affect memory contents)
      .regcea(1'b0),                         // Port A output register enable
      .regceb(1'b1),                         // Port B output register enable
      .douta(),         // Port A RAM output data
      .doutb(read_data)          // Port B RAM output data
  );

  // 8-bit addresses for 2048 bit-numbers
  // addresses for addition
  logic [7:0] number2048_A_pointer;
  logic [7:0] number2048_B_pointer;
  logic [7:0] result4096_pointer; // I reckon it makes more sense 4096 for multiplication

  // adder - arbitrar - memory wires:
  // Request memory read
  logic read_request_pointers_valid;
  logic [7:0] read_request_A_pointer;
  logic [7:0] read_request_B_pointer;
  // Data from requested read
  logic read_request_data_valid;
  logic [31:0] read_request_A_data;
  logic [31:0] read_request_B_data;
  // Write data at address
  logic write_request_valid;
  logic [31:0] write_request_data;
  logic [7:0] write_request_pointer;

  // Recall: start_sum = btn[1];
  logic trigger_sum;
  logic done_sum;
  

  big_adder
  #(
    .BIT_SIZE(2024)
  ) demo_addition 
  (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),

    // Start sum
    .x_pointer_in(number2048_A_pointer),  // pointer to the 2048-bit x number
    .y_pointer_in(number2048_B_pointer),  // pointer to the 2048-bit y number
    .result_pointer_in(result4096_pointer),  // pointer where to store the result 4096-bit number
    .trigger_sum_in(trigger_sum),

    // Request memory read
    .request_valid_out(read_request_pointers_valid),
    .x_request_out(read_request_A_pointer),
    .y_request_out(read_request_B_pointer),

    // Receive data read (32-bit portions of x and y)
    .received_valid_in(read_request_data_valid),
    .x_data_in(read_request_A_data),
    .y_data_in(read_request_B_data),

    // Write data
    .valid_write_out(write_request_valid),
    .data_to_store_out(write_request_data),
    .write_data_pointer_out(write_request_pointer),

    .done_signal_out(done_sum)
  )


  // MEMORY ARBITRAR 
  // probably implement a full arbitrar module instead of having it all in top level
  always_ff @( posedge clk_100mhz ) begin
    
    // Missing because I got too tired
    // In here would be the logic for read/write requests to bram from the sum

  end




endmodule // top_level


`default_ne

