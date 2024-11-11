`default_nettype wire

module big_adder #(
    parameter BIT_SIZE = 2048  // I haven't parametrized it yet lol
)
(
    input wire clk_in,
    input wire rst_in,

    // Start sum
    input wire [7:0] x_pointer_in,  // pointer to the 2048-bit x number
    input wire [7:0] y_pointer_in,  // pointer to the 2048-bit y number
    input wire [7:0] result_pointer_in, // pointer where to store the result 4096-bit number
    input wire trigger_sum_in,

    // Request memory read
    output logic request_valid_out,
    output logic [7:0] x_request_out,
    output logic [7:0] y_request_out,

    // Receive data read (32-bit portions of x and y)
    input wire received_valid_in,
    input wire [31:0] x_data_in,
    input wire [31:0] y_data_in,

    // Write data
    output logic valid_write_out,
    output logic [31:0] data_to_store_out,
    output logic [7:0] write_data_pointer_out,

    output logic done_signal_out
);
// To begin, just a "simple" 2024-bit Ripple-Carry Adder
// Note: can definitely optimize by requesting larger amounts of data
//          though probably more resource intensive, but likely worth it


logic busy; 
logic [7:0] x_pointer;
logic [7:0] y_pointer;
logic [7:0] addr_offset; // 5 bits should work actually
logic carry;
logic final_carry_write;
logic waiting_for_data;

logic [7:0] result_pointer;
logic [7:0] result_addr_offset;

logic [32:0] sum_x_y_blocks;

always_ff @( posedge clk_in ) begin
    if (rst_in) begin
        busy <= 1'b0;
        x_pointer <= 8'b0;
        y_pointer <= 8'b0;
        addr_offset <= 8'b0;
        result_addr_offset <= 8'b0;
        carry <= 1'b0;
        final_carry_write <= 1'b0;
        waiting_for_data <= 1'b0;
        

        request_valid_out <= 1'b0;
        valid_write_out <= 1'b0;
        done_signal_out <= 1'b0;


    end else if (busy) begin
        // Ripple-Carry Adder logic here
        if (!waiting_for_data) begin    // maybe can combine if/else content into one to save a cycle?
            // Not waiting, so
            // request data read (next 32-bit blocks to sum)
            waiting_for_data <= 1'b1;
            valid_write_out <= 1'b0;

            request_valid_out <= 1'b1;
            x_request_out <= x_pointer + addr_offset; // can probably optimize to get rid of this sum
            y_request_out <= y_pointer + addr_offset;

            addr_offset <= addr_offset - 1;

        end else if (received_valid_in || final_carry_write) begin
            // Was waiting, but now just received data
            // write block result 
            waiting_for_data <= 1'b0;

            valid_write_out <= 1'b1;
            data_to_store_out <= (final_carry_write) ? 1
                                : sum_x_y_blocks[31:0];
            carry <= sum_x_y_blocks[32];
            write_data_pointer_out <= result_pointer + result_addr_offset;

            result_addr_offset <= result_addr_offset - 1;

            // just submitted the last block
            if (addr_offset == 0) begin
                // can have a final carry
                final_carry_write <= carry;
                busy <= !carry;
            end

            
            

        end

    end else if (trigger_sum_in) begin
        busy <= 1'b1;
        x_pointer <= x_pointer_in;
        y_pointer <= y_pointer_in;
        result_pointer <= result_pointer_in;
        addr_offset <= 63;  // again, every 2048 bit number is represented as 64 32-bit blocks
                            // x_pointer + addr_offset will point to the least significant block
        carry <= 1'b0;


    end
end

always_comb begin
    sum_x_y_blocks = x_data_in + y_data_in + carry;
end


endmodule

`default_nettype none