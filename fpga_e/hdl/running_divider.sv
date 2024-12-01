`default_nettype none

// Returns the comparison result of up the first NUM_BLOCKS blocks,
// With one cycle delay to receive output of result
module running_divider #(
    parameter REGISTER_SIZE = 32,
    parameter NUM_BLOCKS_IN = 128
)(
    input wire clk_in,
    input wire rst_in,

    input wire valid_in,
    input wire [REGISTER_SIZE-1:0] a_block_in,

    input wire [REGISTER_SIZE-1:0] n_block_in,
    output wire consumed_n_out,
    
    output logic valid_out,
    output logic [REGISTER_SIZE-1:0] r_data_block_out,
    output logic [REGISTER_SIZE-1:0] q_data_block_out
);
    localparam NUM_BLOCKS_OUT = NUM_BLOCKS_IN/2;
    localparam BITS_IN_NUM_IN = REGISTER_SIZE*NUM_BLOCKS_IN;
    localparam BITS_IN_NUM_OUT = BITS_IN_NUM_IN/2;

    enum bit [1:0] {IDLE, COMPARATING, UPDATING, OUTPUTING} state;



    smart_bram_block_combinator #(
        
    ) bram_a_cache (
        .rst_in(),
        .force_write_valid_in(),
        .force_write_block_in(),
        
        .index_in(),
        .activate_index_read_in(),
        .index_read_block_out(),

        .index_write_valid(),
        .index_write_block_in()
    );


    running_comparator #(

    ) compare_a_with_n (

    )

    great_subtractor # (

    ) subtract_a_minus_n (

    )


    smart_bram_block_single_bit_setter # (

    ) bram_q_result (
        
    )



    always_comb begin
       
    end

    always_ff @( posedge clk_in ) begin
        if (rst_in || block_count == NUM_BLOCKS-1) begin
            state <= IDLE;
            block_count <= 0;
        end else if (valid_in) begin 
            // state <= comparison_result_out; // update state. Need to do in case statement because verilog is annoying
            case (comparison_result_out)
            IDLE: 
                state <= IDLE;
            A_LESS_THAN_B:
                state <= A_LESS_THAN_B;
            A_EQUAL_B:
                state <= A_EQUAL_B;
            A_GREATER_THAN_B:
                state <= A_GREATER_THAN_B;
            endcase
            block_count <= block_count + 1;
        end

    end

endmodule

`default_nettype wire