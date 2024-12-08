`timescale 1ns / 1ps
`default_nettype none

module uart_receive
  #(
    parameter INPUT_CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE =  57600
    )
   (
    input wire 	       clk_in,
    input wire 	       rst_in,
    input wire 	       rx_wire_in,
    output logic       new_data_out,
    output logic [7:0] data_byte_out
    );

  localparam BAUD_BIT_PERIOD = INPUT_CLOCK_FREQ / BAUD_RATE;
  localparam BAUD_COUNTER_BITSIZE = $clog2(BAUD_BIT_PERIOD);

  logic [BAUD_COUNTER_BITSIZE-1:0] cycles_counter; 
  
  logic [3:0] state; 
  // 0 idle,
  // 1 start bit,
  // 2 - > 9 data bits
  // 10 -> stop bit
  // 15 -> transmit

  logic [7:0] data_received;

  always @(posedge clk_in ) begin

    // Make new_data_out single cycle
    if (new_data_out) begin
      new_data_out <= 0;
      // data_byte_out <= data_received;
    end

    if (rst_in) begin
      cycles_counter <= 0;
      state <= 4'b0000;

      new_data_out <= 0;
      data_received <= 0;
      data_byte_out <= 0;

    end if (state == 0) begin
      // Begin receiving
      state <= (rx_wire_in) ? 0 : 1; // remain idle if high, start if low
      cycles_counter <= 0;

    end else begin
      
      if ((cycles_counter < ((BAUD_BIT_PERIOD >> 1) + 20)) && (cycles_counter > 1)) begin
        
        if (state == 1) begin
          // Check Start Bit, and offset reading to half period
          cycles_counter <= 0;
          state <= (rx_wire_in) ? 0 : 2;  // Continue only if rx_wire_in == 0
        end else if (state == 15 && (cycles_counter == (BAUD_BIT_PERIOD >> 1))) begin
          // End transmission state
          cycles_counter <= 0;
          state <= 0;
        end else begin
          cycles_counter <= cycles_counter + 1;
        end
      
      end else if (cycles_counter == BAUD_BIT_PERIOD) begin
        // Read on middle of period!
        cycles_counter <= 0;

        // read data
        if (state < 10) begin
          // Save them lsb first format
          data_received <= (data_received >> 1) | (rx_wire_in << 7);
          state <= state + 1;
        end else if (state == 10) begin
          // Stop Bit
          if (rx_wire_in) begin
            // Transmit if 1
            state <= 15;

            // Already perform transmission
            new_data_out <= 1;
            data_byte_out <= data_received;

          end else begin
            // Wrong stop bit (0)
            state <= 0;
          end

        end

      end else begin
        cycles_counter <= cycles_counter + 1;
      end


      


    end
  end

endmodule // uart_receive

`default_nettype wire
