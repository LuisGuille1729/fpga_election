`default_nettype none
module redstone_repeater #(
  parameter BITS_IN_NUM,
  parameter REGISTER_SIZE
) 
(
        input wire clk_in,
        input wire rst_in,

        input wire[REGISTER_SIZE-1:0] data_in,
        input wire data_valid_in,
        input  wire request_next_input,
        output logic [REGISTER_SIZE-1:0] data_out,
        output logic data_valid_out
    );
  //todo actually do this module
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      data_out <= 0;
      data_valid_out <= 0;
    end else begin
      data_out <=  data_in;
      data_valid_out <= data_valid_in;
    end
  end
endmodule
`default_nettype wire