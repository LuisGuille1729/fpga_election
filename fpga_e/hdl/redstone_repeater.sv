`default_nettype none
module redstone_repeater #(
        parameter BITS_IN_NUM = 4096,
        parameter REGISTER_SIZE = 32
    ) (
        input wire clk_in,
        input wire rst_in,

        input wire[REGISTER_SIZE-1:0] data_in,
        input wire data_valid_in,
        input wire prev_data_consumed_in,

        output logic[REGISTER_SIZE-1:0] data_out,
        output logic data_valid_out
    );
    localparam NUM_BLOCKS = BITS_IN_NUM / REGISTER_SIZE;
    localparam BRAM_WIDTH = REGISTER_SIZE;
    localparam BRAM_DEPTH = NUM_BLOCKS;
    logic read_next_chunk_signal;
    enum  {WRITING,OUTPUTTING} repeater_state;

    logic [$clog2(BRAM_DEPTH)-1:0] write_counter_idx;
    evt_counter #(
        .MAX_COUNT(BRAM_DEPTH),
        .COUNT_START(0))
   write_counter_module
    (  
        .clk_in(clk_in),
        .rst_in(rst_in || repeater_state == OUTPUTTING),
        .evt_in(data_valid_in),
        .count_out(write_counter_idx)
    );

    logic [$clog2(BRAM_DEPTH)-1:0] read_counter_idx;
    evt_counter #(
        .MAX_COUNT(BRAM_DEPTH),
        .COUNT_START(0))
   read_counter_module
    (  
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(repeater_state == OUTPUTTING && prev_data_consumed_in),
        .count_out(read_counter_idx)
    );


    always_ff @( posedge clk_in ) begin
        if (rst_in) begin
            repeater_state <= WRITING;
        end else begin
            case (repeater_state)
                WRITING: begin
                    repeater_state <= write_counter_idx== BRAM_DEPTH-1? OUTPUTTING : WRITING;
                end
                OUTPUTTING: begin
                    if (prev_data_consumed_in) begin
                    repeater_state<= read_counter_idx == BRAM_DEPTH-1? WRITING: OUTPUTTING;
                    end
                end
            endcase
        end
    end


    always_comb begin 
        data_valid_out =   repeater_state!= WRITING;
    end
    bram_blocks_rw #(
        .REGISTER_SIZE(REGISTER_SIZE),
        .NUM_BLOCKS(NUM_BLOCKS)
    ) 
    repeater_bram
    (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .write_next_block_valid_in(data_valid_in),   
        .write_block_in(data_in),
        .read_next_block_valid_in(repeater_state == OUTPUTTING && prev_data_consumed_in), 
        .read_block_out(data_out),
        .read_block_pipe2_valid_out()
    );


endmodule
`default_nettype wire