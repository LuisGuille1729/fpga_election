`default_nettype none
// computes addition of 2 numbers by writing to block ram and sending the data back out in cycles
// has a valid out signal and a last signal to showcase a finished addition. 
module byte_repeater  #(
    parameter REGISTER_SIZE = 32,
    parameter BITS_IN_NUM = 4096
    )
    (
        input wire [REGISTER_SIZE-1:0] data_in,
        input wire valid_in,
        input wire request_next_byte_in,
        input wire rst_in,
        input wire clk_in,
        output logic [7:0] data_out,
        output logic valid_out
    );
    localparam NUM_BLOCKS = BITS_IN_NUM / REGISTER_SIZE;
    localparam BRAM_WIDTH = REGISTER_SIZE;
    localparam BRAM_DEPTH = NUM_BLOCKS;
    logic read_next_chunk_signal;
    enum  {WRITING,BYTE0,BYTE1,BYTE2,BYTE3} repeater_state;

    logic [$clog2(BRAM_DEPTH)-1:0] write_counter_idx;
    evt_counter #(
        .MAX_COUNT(BRAM_DEPTH),
        .COUNT_START(0))
   write_counter_module
    (  
        .clk_in(clk_in),
        .rst_in(rst_in || repeater_state == BYTE3),
        .evt_in(valid_in),
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
        .evt_in(repeater_state == BYTE3 &&request_next_byte_in ),
        .count_out(read_counter_idx)
    );


    always_ff @( posedge clk_in ) begin
        if (rst_in) begin
            repeater_state <= WRITING;
        end else begin
            case (repeater_state)
                WRITING: begin
                    repeater_state <= write_counter_idx== BRAM_DEPTH-1? BYTE0 : WRITING;
                end
                BYTE0: begin
                    if (request_next_byte_in) begin
                        repeater_state<= BYTE1;
                    end
                end

                BYTE1: begin
                    if (request_next_byte_in) begin
                    repeater_state<= BYTE2;
                    end
                end
                 
                BYTE2: begin
                    if (request_next_byte_in) begin
                    repeater_state<= BYTE3;
                    end
                end
                BYTE3: begin
                    if (request_next_byte_in) begin
                    repeater_state<= read_counter_idx == BRAM_DEPTH-1? WRITING: BYTE0;
                    end
                end
            endcase
        end
    end

    logic[REGISTER_SIZE-1:0] store_out;

    always_comb begin 
        case (repeater_state)
            BYTE0: data_out = store_out[7:0]; 
            BYTE1: data_out = store_out[15:8];
            BYTE2: data_out = store_out[23:16];
            default: data_out = store_out[31:24];
        endcase
        valid_out =   repeater_state!= WRITING;
    end
    bram_blocks_rw #(
        .REGISTER_SIZE(REGISTER_SIZE),
        .NUM_BLOCKS(NUM_BLOCKS)
    ) 
    repeater_bram
    (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .write_next_block_valid_in(valid_in),   
        .write_block_in(data_in),
        .read_next_block_valid_in(repeater_state == BYTE3 && request_next_byte_in), 
        .read_block_out(store_out),
        .read_block_pipe2_valid_out()
    );





endmodule
`default_nettype wire