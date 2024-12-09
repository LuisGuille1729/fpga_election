`timescale 1ns / 1ps
`default_nettype none

module uart_transmit
     #(parameter INPUT_CLOCK_FREQ = 100_000_000,
       parameter BAUD_RATE = 57600
      )
      (input wire   clk_in, //system clock (100 MHz)
       input wire   rst_in, //reset in signal (active high)
       input wire   [7:0] data_byte_in, //data to send
       input wire   trigger_in, //start a transaction, data_byte_in has valid data

       output logic busy_out, // High if transmitting (tells system no new data will be accepted)
       output logic tx_wire_out // Output signal: start(0)-data(lsb)-end(1). Held high otherwise
      );

  localparam BAUD_BIT_PERIOD = INPUT_CLOCK_FREQ / BAUD_RATE; // Integer division right?
  localparam BAUD_COUNTER_BITSIZE = $clog2(BAUD_BIT_PERIOD);

  logic [BAUD_COUNTER_BITSIZE-1:0] cycles_counter;
  logic is_transmitting;

  logic [7:0] data_to_send;
  logic [7:0] transfer_stage; // one-hot encoding

  always_ff @( posedge clk_in ) begin

    if (rst_in) begin 
      cycles_counter <= 0;

      tx_wire_out <= 1;
      is_transmitting <= 0;
      transfer_stage <= 8'b0000_0000;

      
    end else if (is_transmitting) begin
      // otherwise not resetting but currently transmitting
      if (cycles_counter == BAUD_BIT_PERIOD) begin 
        cycles_counter <= 0;

        // send next lsb
        if (transfer_stage == 0) begin
          // transfer_stage <= 8'b1111_1111; // end transmission after sending stop bit
          tx_wire_out <= 1; // send stop bit
        end else if (transfer_stage == 8'b1111_1111) begin
          is_transmitting <= 0;
        end else begin
          tx_wire_out <= !( (data_to_send & transfer_stage) == 0 );
        end
        transfer_stage <= (transfer_stage == 0) ? 8'b1111_1111 
                      : transfer_stage << 1; // update transfer stage
        

      end else begin
        cycles_counter <= cycles_counter + 1;
      end
      

    end else begin
      // otherwise not resetting and not transmitting
      // Commence transmission 
      if (trigger_in) begin 
       data_to_send <= data_byte_in; 

       tx_wire_out <= 0; // Start bit (0)
       transfer_stage <= 8'b0000_0001;

       is_transmitting <= 1;
       cycles_counter <= 0;
      end

    end

  end

  assign busy_out = is_transmitting;


endmodule

`default_nettype wire