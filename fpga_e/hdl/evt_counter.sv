`default_nettype none
module evt_counter #(
    parameter MAX_COUNT = 128,
    parameter COUNT_START = 0
    ) (  // Slightly modified version of lab 2's event counter
    input wire          clk_in,
    input wire          rst_in,
    input wire          evt_in,
    output logic[$clog2(MAX_COUNT) - 1: 0]  count_out
    );
 
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            count_out <= COUNT_START;
        end else if (evt_in) begin
            if (count_out == MAX_COUNT - 1) count_out <= 0;
            else count_out <= count_out + 1;
        end else begin
            count_out <= count_out;
        end
    end
endmodule
`default_nettype wire