`default_nettype none
module evt_counter #(parameter MAX_COUNT = 1_000_000)
  ( input wire          clk_in,
    input wire          rst_in,
    input wire          evt_in,
    output logic[15:0]  count_out
  );
 
  always_ff @(posedge clk_in) begin
    if (rst_in || count_out == MAX_COUNT) begin
      count_out <= 16'b0;
    end else begin
      count_out <= evt_in ? count_out + 1 : count_out;
    end
  end
endmodule
`default_nettype wire