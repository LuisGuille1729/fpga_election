`default_nettype none
// adds to the stored number in the accumulator the number of size NUM_BITS_STORED. 
// outputs in chunks of register size bits the newly stored number (with natural overflow)
module vote_accumulator_wrapper  #(
    parameter REGISTER_SIZE = 32,
    parameter NUM_BITS_STORED = 4096
    )
    (
        input wire [REGISTER_SIZE-1:0] block_in,
        input wire compute_tally,
        input wire valid_in,
        input wire request_next_in,
        input wire rst_in,
        input wire clk_in,
        output logic [REGISTER_SIZE-1:0] data_out,
        output logic valid_out
    );

    localparam  NUM_BLOCKS = NUM_BITS_STORED/REGISTER_SIZE;

    localparam  BRAM_WIDTH = REGISTER_SIZE;
    localparam BRAM_DEPTH = NUM_BITS_STORED/BRAM_WIDTH;
    logic[$clog2(BRAM_DEPTH)-1:0] output_count;
    enum  {ACCUMULATING,WAIT1,WAIT2,OUTPUTTING} state;
    enum {REQ_WAIT1,REQ_WAIT2,READY} load_states;
    assign valid_out = load_states ==  READY || (state ==OUTPUTTING ) ;
    always_ff @( posedge clk_in ) begin 
        if (rst_in) begin
            output_count <= 0;
            state <= ACCUMULATING;
            load_states <= REQ_WAIT1;            
        end else begin
            if (request_next_in || compute_tally) begin
                load_states<=REQ_WAIT1;
            end else begin
                case (load_states)
                    REQ_WAIT1: load_states<=REQ_WAIT2; 
                    default: load_states <= READY;
                endcase
            end
            case (state)
               ACCUMULATING: state <= compute_tally? WAIT1:state;
               WAIT1: state<= WAIT2;
               WAIT2: state<= OUTPUTTING;
               OUTPUTTING: begin
                if (output_count ==  BRAM_DEPTH-1)begin
                    state <= ACCUMULATING;
                    output_count<=0;
                end else begin 
                    output_count<= output_count+1;
                end
               end 
            endcase
        end
    end

    logic [REGISTER_SIZE-1:0] restore_out;
    bram_blocks_rw #(
        .REGISTER_SIZE(REGISTER_SIZE),
        .NUM_BLOCKS(NUM_BLOCKS),
        .INIT_FILE("R_modN.mem")     
    )
    R_storage
    (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .read_next_block_valid_in(state!=ACCUMULATING), 
        .read_block_out(restore_out),
        .read_block_pipe2_valid_out(),
        .read_done_all_blocks_pipe2_out(), // pipelined as well
        .read_requested_for_last_block(), // unpiped
        .write_next_block_valid_in(),
        .write_block_in()
);


logic read_next;
assign read_next = request_next_in || (state!=ACCUMULATING);

logic write_next;
assign write_next = valid_in || (state == OUTPUTTING);

logic [REGISTER_SIZE-1:0] write_val;
assign write_val = state == OUTPUTTING? restore_out: block_in;

bram_blocks_rw #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS(NUM_BLOCKS),
    .INIT_FILE("R_modN.mem")     

)
vote_accumulator
 (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .read_next_block_valid_in(read_next), 
    .read_block_out(data_out),
    .read_block_pipe2_valid_out(),
    .read_done_all_blocks_pipe2_out(), // pipelined as well
    .read_requested_for_last_block(), // unpiped
    
    .write_next_block_valid_in(write_next),
    .write_block_in()
);
endmodule
`default_nettype wire