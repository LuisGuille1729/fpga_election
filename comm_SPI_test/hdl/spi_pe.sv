`timescale 1ns / 1ps
`default_nettype none

module spi_pe
     #(parameter DATA_WIDTH = 8
      )
      (input wire   clk_in, //system clock (100 MHz)
       input wire   rst_in, //reset in signal
       input wire   [DATA_WIDTH-1:0] data_in, //data to send
      //  input wire   trigger_in, //store data to be sent
      input wire valid_in, // valid data to send
      output logic [DATA_WIDTH-1:0] data_out, //data received!
      output logic data_valid_out, //high when output data is present.
 
      //  output logic chip_data_out, //(COPI)
      //  input wire   chip_data_in, //(CIPO)
      //  output logic chip_clk_out, //(DCLK)
      //  output logic chip_sel_out // (CS)
        input wire chip_data_in, //(COPI)
        output logic   chip_data_out, //(CIPO)
        input wire chip_clk_in, //(DCLK)
        input wire chip_sel_in // (CS) 
      );

  logic [$clog2(DATA_WIDTH):0] bits_read_counter; 

  logic transaction_active;
  assign transaction_active = !chip_sel_in;

  logic rising_edge;
  logic falling_edge;
  logic prev_dclk;
  always_ff @( posedge clk_in ) begin
    
    prev_dclk <= chip_clk_in;

    if (rst_in) begin
        rising_edge <= 0;
        falling_edge <= 0;
    end else begin
      rising_edge <= chip_clk_in & !prev_dclk;
      falling_edge <= !chip_clk_in & prev_dclk;
    end
  end
  

  logic [DATA_WIDTH-1:0] data_to_send;
  logic [DATA_WIDTH-1:0] data_received;
  logic [DATA_WIDTH-1:0] transfer_stage; // expressed in one-hot encoding for ease

  always_ff @( posedge clk_in ) begin
    if (rst_in) begin
      data_out  <= 1'b0;
      data_valid_out <= 1'b0;
      data_to_send <= 0;

      bits_read_counter <= 1'b0;
      data_received <= 0;

    end else begin

      if (valid_in) data_to_send <= data_in; // data to be send via CIPO

      if (transaction_active) begin // CS is down

        if (rising_edge) begin //READ COPI
          data_received <= {data_received, chip_data_in};
          bits_read_counter <= bits_read_counter + 1;
        end

        if (falling_edge) begin // WRITE CIPO
          chip_data_out <= data_to_send[DATA_WIDTH-1]; // msb
          data_to_send <= data_to_send << 1;
        end

      end // transaction_active

      
      // done reading, output read data
      if (bits_read_counter == DATA_WIDTH) begin 
        bits_read_counter <= 0;
        data_out <= data_received;
        data_received <= 0;
        data_valid_out <= 1;
      end

      // ensure only one cycle of data_valid_out
      if (data_valid_out) begin
        data_valid_out <= 0; 
      end


    end

  end


endmodule

`default_nettype wire