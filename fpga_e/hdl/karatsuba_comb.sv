// `default_nettype none
// // computes addition of 2 numbers by writing to block ram and sending the data back out in cycles
// // has a valid out signal and a last signal to showcase a finished addition. 
// module karatsuba_comb  #(
//     parameter REGISTER_SIZE = 64
//     )
//     (   
//         input wire clk_in, //only for testing
//         input wire [REGISTER_SIZE-1:0] x_in,
//         input wire [REGISTER_SIZE-1:0] y_in,
//         output logic [OUT_SIZE-1:0] data_out
//     );
//     localparam OUT_SIZE = 2*REGISTER_SIZE;
//     localparam HALF_SIZE = REGISTER_SIZE/2;

//     logic [HALF_SIZE-1:0] x_low;
//     logic [HALF_SIZE-1:0] x_top;
//     logic [HALF_SIZE-1:0] y_low;
//     logic [HALF_SIZE-1:0] y_top;

//     assign x_low = x_in[HALF_SIZE-1:0];
//     assign x_top = x_in[REGISTER_SIZE-1:HALF_SIZE];
//     assign y_low = y_in[HALF_SIZE-1:0];
//     assign y_top = y_in[REGISTER_SIZE-1:HALF_SIZE];


//     logic [REGISTER_SIZE-1:0] z_0;
//     logic [REGISTER_SIZE:0] z_1;
//     logic [REGISTER_SIZE-1:0] z_2;
//     logic [REGISTER_SIZE+1:0] z_3;

//     always_comb begin
//         z_3 = (x_low + x_top) * (y_low + y_top);
//         z_2 = x_top * y_top;
//         z_0 = x_low * y_low;
//         z_1 = z_3 - z_2 - z_0;

//         data_out = (z_2 << REGISTER_SIZE) + (z_1 << HALF_SIZE) + z_0;
//     end

// endmodule
// `default_nettype wire