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

    localparam BRAM_WIDTH = REGISTER_SIZE;
    localparam BRAM_DEPTH = BITS_IN_NUM / REGISTER_SIZE;
    localparam MAX_ADDRESS = BRAM_DEPTH;
    localparam ADDRESS_SIZE = $clog2(MAX_ADDRESS);

    logic busy;
    logic done_writing;
    logic [ADDRESS_SIZE-1:0] next_addra;
    logic [ADDRESS_SIZE-1:0] next_addrb;
    logic valid_out_pipe [1:0];

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            busy <= 0;
            done_writing <= 0;
            next_addra <= 0;
            next_addrb <= 0;

            data_valid_out <= 0;
            valid_out_pipe[0] <= 0;
        end
        else if (data_valid_in) begin
            busy <= 1;
            if (next_addrb == MAX_ADDRESS - 1) begin
                done_writing <= 1;  // Should no longer increment next_addrb, even though it doesn't really matter
            end
            else begin
                next_addrb <= next_addrb + 1;
            end
        end
        else if (busy) begin
            if ((next_addra == MAX_ADDRESS - 1) && prev_data_consumed_in) begin
                busy <= 0;
                done_writing <= 0;
                next_addra <= 0;
                next_addrb <= 0;

                data_valid_out <= 0;
                valid_out_pipe[0] <= 1;
            end
            else if (done_writing & prev_data_consumed_in) begin
                valid_out_pipe[0] <= 1;
                next_addra <= next_addra + 1;
            end
            else begin
                valid_out_pipe[0] <= 0;
            end
        end
        else begin
            valid_out_pipe[0] <= 0;
        end

        data_valid_out <= rst_in ? 0 : valid_out_pipe[0];
        valid_out_pipe[1] <= rst_in ? 0 : valid_out_pipe[0];
    end

    xilinx_true_dual_port_read_first_2_clock_ram
     #(
        .RAM_WIDTH(BRAM_WIDTH),
        .RAM_DEPTH(BRAM_DEPTH)) encryptor_bram  // Stores the outputs from the encryptor
       (
        // PORT A
        .addra(next_addra),
        .dina(),
        .clka(clk_in),
        .wea(1'b0),
        .ena(1'b1),
        .rsta(rst_in),
        .regcea(1'b1),
        .douta(data_out),
        // PORT B
        .addrb(next_addrb),
        .dinb(data_in),
        .clkb(clk_in),
        .web(data_valid_in),
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );
endmodule
`default_nettype wire