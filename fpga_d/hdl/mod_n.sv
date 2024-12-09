`default_nettype none
// computes addition of 2 numbers by writing to block ram and sending the data back out in cycles
// has a valid out signal and a last signal to showcase a finished addition. 
module mod_n  #(
    parameter REGISTER_SIZE = 32,
    parameter BITS_IN_NUM = 4096
    )
    (
        input wire [REGISTER_SIZE-1:0] num_in,
        input wire valid_in,
        input wire rst_in,
        input wire clk_in,
        output logic [REGISTER_SIZE-1:0] data_out,
        output logic valid_out
    );

localparam NUM_BLOCKS_IN = BITS_IN_NUM/REGISTER_SIZE;
localparam BRAM_WIDTH = REGISTER_SIZE;
localparam BRAM_DEPTH = NUM_BLOCKS_IN;

logic [$clog2(BRAM_DEPTH)-1:0] addra;
logic [$clog2(BRAM_DEPTH)-1:0] addrb;

logic [REGISTER_SIZE-1:0] reg0;
logic [REGISTER_SIZE-1:0] reg1;
logic mul_trigger;

logic [REGISTER_SIZE-1:0] douta;


enum  {write1,write2,write_stream, ready_idle, output2_idle, outputing_stream} res_state; 

always_ff @( posedge clk_in ) begin 
    if (rst_in) begin
        res_state <= write1;
        addra <=2;
        addrb <=0;
    end else begin
        case (res_state)
            write1: begin
                if (valid_in) begin
                    res_state <=write2;
                    reg0<= num_in;
                    addrb<= addrb+1;
                end
            end 
            write2: begin
                if (valid_in) begin
                    res_state <= write_stream;
                    reg1<= num_in;
                    addrb<= addrb+1;
                end
            end
            write_stream: begin
                if (valid_in) begin
                    if (addrb == BRAM_DEPTH-1) begin
                        res_state <= ready_idle;
                        addrb<=0;
                    end else begin
                        addrb <= addrb+1;
                    end
                end
            end
            ready_idle : begin
                if (mul_trigger) begin
                    res_state <= output2_idle;
                    addra<= addra +1;
                end
            end
            output2_idle: begin
                addra<= addra +1;
                res_state <= outputing_stream;
            end
            outputing_stream: begin
                if (addra == 1) begin
                    res_state <= write1;
                end 
                addra <= addra +1;
            end   
        endcase
    end
end

    logic valid_divider_out;
    logic [REGISTER_SIZE-1:0] divider_out;

    fixed_divider #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .NUM_BLOCKS_IN(NUM_BLOCKS_IN),
    //idk what this is
    // parameter BITS_EXPONENT = 6080, // only change if changing divider n
    .NUM_BLOCKS_OUT(NUM_BLOCKS_IN/2)
) cool(
    .clk_in(clk_in),
    .rst_in(rst_in),

    .valid_in(valid_in),
    .x_block_in(num_in),   // the number we want to divide by
    
    // input wire [REGISTER_SIZE-1:0] mult_inv_constant_block_in, // we implement in top level so that it is paired at the same time with the corresponding x_block_in. In future, can implement this directly.

    .valid_out(valid_divider_out),
    .data_block_out(divider_out)
);

    logic[REGISTER_SIZE-1:0] n_data_out;
   n_multiplier  #(
    .REGISTER_SIZE (REGISTER_SIZE),
    .BITS_IN_NUM(BITS_IN_NUM/2)
    )
    ner
    (
        .n_in(divider_out),
        .valid_in(valid_divider_out),
        .rst_in(rst_in),
        .clk_in(clk_in),
        .data_out(n_data_out),
        .valid_out(mul_trigger),
        .final_out(),
        .ready_out()
    );




    logic[REGISTER_SIZE-1:0] num_used;

    always_comb begin 
        case (res_state)
            ready_idle: num_used = reg0;
            output2_idle: num_used = reg1;  
            default:  num_used = douta;
        endcase
    end 


    great_subtractor  #(
    .REGISTER_SIZE(REGISTER_SIZE),
    .BITS_IN_NUM(BITS_IN_NUM)
    )
    final_subtractor
    (
        .a_in(num_used),
        .b_in(n_data_out),
        // input wire carry_in,
        .valid_in(mul_trigger),
        .rst_in(rst_in),
        .clk_in(clk_in),
        .data_out(data_out),
        // output logic sign_out,
        .valid_out(valid_out),
        .final_out()
    );
















xilinx_true_dual_port_read_first_2_clock_ram
     #(.RAM_WIDTH(BRAM_WIDTH),
       .RAM_DEPTH(BRAM_DEPTH)       
       ) const_storage_bram
       (
        // PORT A
        .addra(addra),
        .dina(0), // we only use port A for reads!
        .clka(clk_in),
        .wea(1'b0), // read only
        .ena(1'b1),
        .rsta(rst_in),
        .regcea(1'b1),
        .douta(douta),
        // PORT B
        .addrb(addrb),
        .dinb(num_in),
        .clkb(clk_in),
        .web(1'b1),
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );





endmodule
`default_nettype wire