`default_nettype none
// computes addition of 2 numbers by writing to block ram and sending the data back out in cycles
// has a valid out signal and a last signal to showcase a finished addition. 
module padder  #(
    parameter REGISTER_SIZE = 32,
    parameter BITS_IN_NUM = 4096,
    parameter NUM_PADS = BITS_IN_NUM
    )
    (
        input wire [REGISTER_SIZE-1:0] data_in,
        input wire valid_in,
        input wire rst_in,
        input wire clk_in,
        output logic [REGISTER_SIZE-1:0] data_out,
        output logic valid_out
    );

    localparam TOTAL_SENDS = (NUM_PADS + BITS_IN_NUM)/REGISTER_SIZE;

    localparam INPUT_CUTOFF = (BITS_IN_NUM)/ REGISTER_SIZE;


    logic [$clog2(TOTAL_SENDS)-1:0] send_counter;
    assign valid_out = valid_in||send_counter>=INPUT_CUTOFF;
evt_counter #(
    .MAX_COUNT(TOTAL_SENDS),
    .COUNT_START(0))
 pad_counter
(  
    .clk_in(clk_in),
    .rst_in(rst_in),
    .evt_in(valid_out),
    .count_out(send_counter)
);

assign data_out = send_counter < INPUT_CUTOFF? data_in: 0;




endmodule
`default_nettype wire