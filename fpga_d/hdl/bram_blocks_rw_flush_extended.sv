`default_nettype none

module bram_blocks_rw_flush_extended #(
    parameter REGISTER_SIZE = 32,
    parameter NUM_BLOCKS = 128,
    parameter INIT_FILE = ""      

) (
    input wire clk_in,
    input wire rst_in,

    input wire read_next_block_valid_in,
    input wire flush, 
    output logic [REGISTER_SIZE-1:0] read_block_out,
    output logic read_block_pipe2_valid_out,
    output logic read_done_all_blocks_pipe2_out, // pipelined as well
    output logic read_requested_for_last_block, // unpiped
    output logic flush_valid,
    input wire write_next_block_valid_in,
    input wire [REGISTER_SIZE-1:0] write_block_in
);

// Facilitates reading and writting continuous blocks to BRAM 
// Recall we will still have a 2-cycle delay for BRAM
enum  {NONE, SHIFTING, FLUSHING, DONE} flush_states;
logic force_read;
// Counter of Read Address (increments every read_next_block_valid_in)
logic [$clog2(NUM_BLOCKS)-1:0] address_of_read_block;
evt_counter #(
    .MAX_COUNT(NUM_BLOCKS),
    .COUNT_START(0))
 read_address_counter
(  
    .clk_in(clk_in),
    .rst_in(rst_in),
    .evt_in(read_next_block_valid_in || force_read),
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

assign read_requested_for_last_block = address_of_read_block == (NUM_BLOCKS-1);

pipeliner#(
        .PIPELINE_STAGE_COUNT(2),
        .DATA_BIT_SIZE(1)
    )
    flush_valid_pipe (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .data_in(flush_states == FLUSHING),
        .data_out(flush_valid)
    );
logic [$clog2(NUM_BLOCKS)-1:0] sent_counter;


logic valid_pipe1;
logic read_all_pipe1;
always_ff @( posedge clk_in ) begin
    if (rst_in) begin        
        valid_pipe1 <= 0;
        read_block_pipe2_valid_out <= 0;

        read_all_pipe1 <= 0;
        read_done_all_blocks_pipe2_out <= 0;
        flush_states<=NONE;
        force_read<=1;
    end else begin
        case (flush_states)
            NONE:begin 
                sent_counter<=0;
                flush_states<= flush? SHIFTING:NONE;
                force_read<= flush? 1: force_read;
            end 
            SHIFTING: begin
                flush_states<= address_of_read_block == NUM_BLOCKS-1? FLUSHING: SHIFTING;
            end
            FLUSHING: begin
                sent_counter<= sent_counter+1;
                flush_states<= sent_counter == NUM_BLOCKS-1? DONE:FLUSHING;
                force_read<= sent_counter == NUM_BLOCKS-1? 0: force_read;
            end 
        endcase
        valid_pipe1 <= read_next_block_valid_in;
        read_block_pipe2_valid_out <= valid_pipe1;  // give signal when read value has been obtained
        
        read_all_pipe1 <= address_of_read_block == (NUM_BLOCKS-1);
        read_done_all_blocks_pipe2_out <= read_all_pipe1;

    end

end

// BRAM
xilinx_true_dual_port_read_first_2_clock_ram
#(
    .RAM_WIDTH(REGISTER_SIZE),
    .RAM_DEPTH(NUM_BLOCKS),
    .INIT_FILE(INIT_FILE)
    )    
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