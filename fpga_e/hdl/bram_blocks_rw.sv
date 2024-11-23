`default_nettype none

module bram_blocks_rw #(
    parameter REGISTER_SIZE = 32,
    parameter NUM_BLOCKS = 128
) (
    input wire clk_in,
    input wire rst_in,

    input wire read_next_block_valid_in, 
    output logic [REGISTER_SIZE-1:0] read_block_out,
    output logic read_block_pipe2_valid_out,
    output logic read_done_all_blocks_out, // pipelined as well
    
    input wire write_next_block_valid_in,
    input wire [REGISTER_SIZE-1:0] write_block_in
);

// Facilitates reading and writting continuous blocks to BRAM 
// Recall we will still have a 2-cycle delay for BRAM

// Counter of Read Address (increments every read_next_block_valid_in)
logic [$clog2(NUM_BLOCKS)-1:0] address_of_read_block;
evt_counter #(
    .MAX_COUNT(NUM_BLOCKS),
    .COUNT_START(0))
 read_address_counter
(  
    .clk_in(clk_in),
    .rst_in(rst_in),
    .evt_in(read_next_block_valid_in),
    .count_out(address_of_read_block)
);

// Counter of Write Address (increments every write_next_block_valid_in)
logic [$clog2(NUM_BLOCKS)-1:0] address_of_write_block;
evt_counter #(
    .MAX_COUNT(NUM_BLOCKS),
    .COUNT_START(0))
 write_address_counter
(  
    .clk_in(clk_in),
    .rst_in(rst_in),
    .evt_in(write_next_block_valid_in),
    .count_out(address_of_write_block)
);

logic valid_pipe1;
logic read_all_pipe1;
always_ff @( posedge clk_in ) begin
    if (rst_in) begin
        read_done_all_blocks_out <= 0;
    end else begin
        valid_pipe1 <= read_next_block_valid_in;
        read_block_pipe2_valid_out <= valid_pipe1;  // give signal when read value has been obtained
        
        read_all_pipe1 <= address_of_read_block == (NUM_BLOCKS-1);
        read_done_all_blocks_out <= read_all_pipe1;

    end

end

// BRAM
xilinx_true_dual_port_read_first_2_clock_ram
#(
    .RAM_WIDTH(REGISTER_SIZE),
    .RAM_DEPTH(NUM_BLOCKS))
bram
    (
    // PORT A - READ
    .addra(address_of_read_block),
    .dina(0), // we only use port A for reads!
    .clka(clk_in),
    .wea(1'b0), // read only
    .ena(1'b1),
    .rsta(rst_in),
    .regcea(1'b1),
    .douta(read_block_out),
    // PORT B - WRITE
    .addrb(address_of_write_block),
    .dinb(write_block_in),
    .clkb(clk_in),
    .web(write_next_block_valid_in), // write always, NOTE cannot just do 1'b1
    .enb(1'b1),
    .rstb(rst_in),
    .regceb(1'b1),
    .doutb() // we only use port B for writes!
);



endmodule

`default_nettype wire