`default_nettype none
module right_shifter #(
    parameter REGISTER_SIZE = 32,
    parameter NUM_BLOCKS = 256,
    parameter SHIFT_BY = 4096
)(
    input wire clk_in,
    input wire rst_in,

    input wire valid_in,
    input wire [REGISTER_SIZE-1:0] block_in,  
    
    output logic valid_out,
    output logic [REGISTER_SIZE-1:0] data_block_out
);

// For better performance,
// Assumes that SHIFT_BY will always be a power of 2
// and that SHIFT_BY will always be a product of REGISTER_SIZE

localparam BLOCKS_TO_IGNORE = SHIFT_BY/REGISTER_SIZE;

logic [$clog2(BLOCKS_TO_IGNORE):0] blocks_to_ignore;
logic [$clog2(NUM_BLOCKS):0] blocks_to_receive;

// Outputs the received block_in with appropiate valid_out signal.
assign data_block_out = block_in;
assign valid_out = valid_in && (blocks_to_ignore == 0);

always_ff @( posedge clk_in ) begin
    if (rst_in || blocks_to_receive == 0) begin
        blocks_to_ignore <= BLOCKS_TO_IGNORE;
        blocks_to_receive <= NUM_BLOCKS;
    end else if (valid_in) begin
        blocks_to_ignore <= (blocks_to_ignore == 0) ? 0 : blocks_to_ignore - 1;
        blocks_to_receive <= blocks_to_receive - 1;
    end
end


endmodule

`default_ne