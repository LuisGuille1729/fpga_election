`default_nettype none
module montgomery_squarer_stream #(
    parameter REGISTER_SIZE = 32,
    parameter BITS_IN_NUM = 2048,
    parameter R = 4096
) (
    input wire clk_in,
    input wire rst_in,

    input wire [REGISTER_SIZE-1:0] N_in,
    input wire [REGISTER_SIZE-1:0] k_in,
    
    input wire [REGISTER_SIZE-1:0] reduced_modulo_block_in,
    input wire data_valid_in,

    output logic consumed_k_out,
    output logic consumed_N_out,

    output logic [BITS_IN_OUT-1:0] reduced_square_out,
    output logic squared_valid_out,
    output logic ready_out
);

    localparam BITS_IN_OUT = 2 * BITS_IN_NUM;  // 2*BITS_IN_NUM bit output from montgomery passed into multiplier, passed into montgomery
    localparam NUM_BLOCKS = 2 * BITS_IN_OUT / REGISTER_SIZE;
    localparam HIGHEST_EXPONENT = $clog2(BITS_IN_NUM);

    logic [$clog2(NUM_BLOCKS)-1:0] block_ctr;
    logic [$clog2(HIGHEST_EXPONENT)-1:0] square_exponent_ctr;
    logic [REGISTER_SIZE-1:0] squared_modulo_block;
    logic initial_state;

    assign squared_modulo_block = data_valid_in ? reduced_modulo_block_in : reducer_block_out;
    assign reduced_square_out = rst_in ? 0 : squared_modulo_block;
    // assign valid_out = rst_in ? 0 : (data_valid_in & initial_state) | reducer_valid_out;  // TODO - Keep initial_state as a bit rather than enum?

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            initial_state <= 1;
            block_ctr <= 0;
            square_exponent_ctr <= 0;

            squared_valid_out <= 0;
            ready_out <= 1;
        end
        else if ((data_valid_in & initial_state) | reducer_valid_out) begin
            squared_valid_out <= 1;
            if (block_ctr == NUM_BLOCKS - 1) begin
                block_ctr <= 0;
                square_exponent_ctr <= (square_exponent_ctr == HIGHEST_EXPONENT - 1) ? 0 : square_exponent_ctr + 1;
                if (square_exponent_ctr == HIGHEST_EXPONENT - 1) begin
                    square_exponent_ctr <= 0;
                    initial_state <= 1;
                    ready_out <= 1;
                end
                else begin
                    square_exponent_ctr <= square_exponent_ctr + 1;
                    initial_state <= 0;
                    ready_out <= 0;
                end
            end
            else begin
                block_ctr <= block_ctr + 1;
                ready_out <= 0;
            end
        end
        else begin
            squared_valid_out <= 0;
            ready_out <= 0;
        end
    end

    logic multiplier_valid_out;
    logic [REGISTER_SIZE-1:0] multiplier_block_out;
    fsm_multiplier #(
        .REGISTER_SIZE(REGISTER_SIZE),
        .BITS_IN_NUM(BITS_IN_NUM)
    ) squarer_stream_multiplier (
        .n_in(squared_modulo_block),
        .m_in(squared_modulo_block),
        .valid_in((initial_state & data_valid_in) | ((~initial_state) & reducer_valid_out)),
        .rst_in(rst_in),
        .clk_in(clk_in),
        .data_out(multiplier_block_out),
        .valid_out(multiplier_valid_out),
        .final_out(),
        .ready_out()
    );

    logic reducer_valid_out;
    logic [REGISTER_SIZE-1:0] reducer_block_out;
    montgomery_reduce #(
        .REGISTER_SIZE(REGISTER_SIZE),
        .NUM_BLOCKS(NUM_BLOCKS),
        .R(R)
    ) squarer_stream_reducer (
        .clk_in(clk_in),
        .rst_in(rst_in),

        .valid_in(multiplier_valid_out),
        .T_block_in(multiplier_block_out),

        .k_constant_block_in(k_in),
        .consumed_k_out(consumed_k_out),

        .modN_constant_block_in(N_in),
        .consumed_N_out(consumed_N_out),

        .valid_out(reducer_valid_out),
        .data_block_out(reducer_block_out)
    );
endmodule
`default_nettype wire