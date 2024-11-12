`default_nettype none
module pipeliner  #(
    parameter PIPELINE_STAGE_COUNT = 1,
    parameter  DATA_BIT_SIZE= 1 )
    (
        input wire clk_in,
        input wire rst_in,
        input wire[DATA_BIT_SIZE-1:0] data_in,
        output logic[DATA_BIT_SIZE-1:0] data_out
    );


    logic [DATA_BIT_SIZE-1:0] data_pipe [PIPELINE_STAGE_COUNT-1:0];
    assign data_out = data_pipe[PIPELINE_STAGE_COUNT-1]; 
    always_ff @(posedge clk_in)begin
        if (rst_in) begin
            for (int i=0; i<PIPELINE_STAGE_COUNT; i = i+1)begin
                data_pipe[i] <= 0;
            end
            
        end else begin
            data_pipe[0]<= data_in;
            for (int i=1; i<PIPELINE_STAGE_COUNT; i = i+1)begin
                data_pipe[i] <= data_pipe[i-1];
            end
        end
    end

endmodule

`default_nettype wire
