
module LFSR32Fake (
    input wire rst_in,
    input wire clk_in,
    input wire trigger_in,
    output logic [31:0] rand_out,
    output logic valid_out
    );

logic[31:0] feedback;

logic [31:0] random, random_next, random_done;

localparam REGISTER_SIZE = 32;
localparam NUM_BLOCKS = 4096/REGISTER_SIZE;
logic[$clog2(NUM_BLOCKS):0] curr_count;


assign valid_out = curr_count <NUM_BLOCKS;


assign rand_out = curr_count == 0? 1: 0;
always_ff @(posedge clk_in) begin
    if (rst_in) begin
        curr_count <= NUM_BLOCKS;
    end else begin
        curr_count <= trigger_in? 0: curr_count< NUM_BLOCKS? curr_count+1: curr_count;
    end   
end

endmodule 