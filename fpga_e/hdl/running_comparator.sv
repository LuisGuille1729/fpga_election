`default_nettype none

module running_comparator #(
    parameter REGISTER_SIZE = 32,
    parameter NUM_BLOCKS = 128
)(
    input wire clk_in,
    input wire rst_in,

    input wire valid_in,
    input wire [REGISTER_SIZE-1:0] block_numA_in,
    input wire [REGISTER_SIZE-1:0] block_numB_in,
    
    // Output is:
    // 00 - NULL
    // 01 - A less than B
    // 10 - A greater than B
    // 11 - A equals B
    output logic [1:0] comparison_result_out
);

    enum {IDLE=0, A_LESS_THAN_B=1, A_EQUAL_B=2, A_GREATER_THAN_B=3} state;
    // Note: See lucid-chart for FSM diagram
    // https://lucid.app/lucidchart/f2744b53-02a1-47fa-b0ea-dd6aaf4cb5ec/edit?invitationId=inv_78c14da0-c287-4d73-a1f3-bd751441b047&page=KcXtH5rtSSBn#

    assign comparison_result_out = state;

    logic [$clog2(NUM_BLOCKS)-1:0] block_count;

    always_ff @( posedge clk_in ) begin
        if (rst_in) begin
            state <= IDLE;
            block_count <= 0;
        end
        else if (block_count == NUM_BLOCKS-1) begin
            block_count <= 0;

            if (valid_in) begin
                if (block_numA_in == block_numB_in)
                        state <= A_EQUAL_B;
                    else if (block_numA_in < block_numB_in)
                        state <= A_LESS_THAN_B;
                    else
                        state <= A_GREATER_THAN_B;
            end
            else state <= IDLE;


        end else if (valid_in) begin
            case (state)
                IDLE: begin
                    if (block_numA_in == block_numB_in)
                        state <= A_EQUAL_B;
                    else if (block_numA_in < block_numB_in)
                        state <= A_LESS_THAN_B;
                    else
                        state <= A_GREATER_THAN_B;
                end

                A_LESS_THAN_B: begin
                    if (block_numA_in > block_numB_in)
                        state <= A_GREATER_THAN_B;
                    // else A_LESS_THAN_B
                end

                A_EQUAL_B: begin
                    if (block_numA_in < block_numB_in)
                        state <= A_LESS_THAN_B;
                    else if (block_numA_in > block_numB_in)
                        state <= A_GREATER_THAN_B;
                    // else A_EQUAL_B
                end

                A_GREATER_THAN_B: begin
                    if (block_numA_in < block_numB_in)
                        state <= A_LESS_THAN_B;
                    // else A_GREATER_THAN_B
                end



            endcase
        end

    end


endmodule

`default_nettype wire