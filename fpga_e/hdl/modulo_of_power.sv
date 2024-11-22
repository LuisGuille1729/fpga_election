`default_nettype none
module modulo_of_power #(
    parameter REGISTER_SIZE = 32,
    parameter NUM_BLOCKS = 256,
    parameter MODULO = 4096
)(
    input wire clk_in,
    input wire rst_in,

    input wire valid_in,
    input wire [REGISTER_SIZE-1:0] block_in,  
    
    output logic valid_out,
    output logic [REGISTER_SIZE-1:0] data_block_out
);

// For better performance,
// Assumes that MODULO will always be a power of 2
// and that MODULO will always be a product of REGISTER_SIZE

localparam BLOCKS_IN_RESULT = MODULO/REGISTER_SIZE;

logic [$clog2(BLOCKS_IN_RESULT):0] blocks_to_output;
logic [$clog2(NUM_BLOCKS):0] blocks_to_receive;

// Outputs the received block_in with appropiate valid_out signal.
assign data_block_out = block_in;
assign valid_out = valid_in && (blocks_to_output != 0);

always_ff @( posedge clk_in ) begin
    if (rst_in || blocks_to_receive == 0) begin
        blocks_to_output <= BLOCKS_IN_RESULT;
        blocks_to_receive <= NUM_BLOCKS;
    end else if (valid_in) begin
        blocks_to_output <= (blocks_to_output == 0) ? 0 : blocks_to_output - 1;
        blocks_to_receive <= blocks_to_receive - 1;
    end
end


endmodule

`default_nettype wire