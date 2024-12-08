`timescale 1ns / 1ps
`default_nettype none

module spi_con
     #(parameter DATA_WIDTH = 8,
       parameter DATA_CLK_PERIOD = 100
      )
      (input wire   clk_in, //system clock (100 MHz)
       input wire   rst_in, //reset in signal
       input wire   [DATA_WIDTH-1:0] data_in, //data to send
       input wire   trigger_in, //start a transaction
       output logic [DATA_WIDTH-1:0] data_out, //data received!
       output logic data_valid_out, //high when output data is present.
 
       output logic chip_data_out, //(COPI)
       input wire   chip_data_in, //(CIPO)
       output logic chip_clk_out, //(DCLK)
       output logic chip_sel_out // (CS)
      );

  // ensure that CLK_PERIOD is even. e.g. 39 -> 38
  parameter HALF_CLK_PERIOD = int'($floor(DATA_CLK_PERIOD/2)); 
  parameter CLK_BITSIZE = int'($clog2(HALF_CLK_PERIOD));

  logic inner_clk;
  logic [CLK_BITSIZE-1:0] cycles_counter; //? no need to initialize to zero?

  logic began_transferring;
  logic [DATA_WIDTH-1:0] send_data;
  logic [DATA_WIDTH-1:0] data_received;
  logic [DATA_WIDTH-1:0] transfer_stage; // expressed in one-hot encoding for ease

  always_ff @( posedge clk_in ) begin

    if (rst_in) begin // when reset
      cycles_counter <= 0;
      data_out  <= 1'b0;
      data_valid_out <= 1'b0;
      chip_data_out <= 1'b0;
      inner_clk <= 1'b0;
      chip_sel_out <= 1'b1;   //??? or just let it be unchanged?

      began_transferring <= 1'b0;
      transfer_stage <= 1'b0;
      data_received <= 0;

    end else begin 
    // otherwise not resetting

      // Begin transfer
      if (trigger_in && !began_transferring) begin // triggered, record data_in, begin transfer
        began_transferring <= 1'b1;
        transfer_stage <= 1 << (DATA_WIDTH-1);

        send_data <= data_in; // store current data_in

        // send out first bit
        chip_data_out <= !((data_in & (1 << (DATA_WIDTH-1))) == 0); 

      end    
    
      if (began_transferring) begin
      chip_sel_out <= 0;

      // Logic for inner_clk
      if (cycles_counter == HALF_CLK_PERIOD) begin  // when reached edge
        if (transfer_stage == 0) begin // if finished sending
            began_transferring <= 1'b0;
            chip_sel_out <= 1'b1;
            data_out <= data_received;
            data_valid_out <= 1;
            // data_received <= 0;
        end if (inner_clk) begin // Falling edge (write)
          chip_data_out <= !((send_data & transfer_stage) == 0);
        end else begin  // Rising edge (read)
          data_received <= {data_received, chip_data_in};
          transfer_stage <= transfer_stage >> 1;

        end 
        inner_clk <= ~inner_clk;
        cycles_counter <= 0;

      end else begin  // when not in edge
        cycles_counter <= cycles_counter + 1'b1;
      end  
    end // if (began_transferring)

    if (data_valid_out) begin
      data_valid_out <= 1'b0;
    end

    end // else not rst_in


end



assign chip_clk_out = rst_in ? 0 : inner_clk;

endmodule

`default_nettype wire