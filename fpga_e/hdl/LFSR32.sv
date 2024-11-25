
module LFSR32 (
    input wire rst_in,
    input wire clk_in,
    output logic [31:0] rand_out,
    output logic valid_out
    );

logic[31:0] feedback;

logic [31:0] random, random_next, random_done;

assign rand_out = feedback;



always_ff @(posedge clk_in) begin
    if (rst_in) begin
        feedback <= 32'hffffffffffffffff;
    end else begin
        feedback <= {feedback[30:0],feedback[31] ^ feedback[21] ^ feedback[1] ^ feedback[0]};
    end   
end

endmodule 