`default_nettype none
// computes addition of 2 numbers by writting to block ram and sending the data back out in cycles
// has a valid out signal and a last signal to showcase a finished addition. 
module fsm_adder  #(
    parameter register_size = 32,
    parameter bits_in_num = 2048
    )
    (
        input wire [register_size-1:0] chunk_in,
        input wire valid_in,
        input wire rst_in,
        input wire clk_in,
        output logic [register_size-1:0] data_out,
        output logic carry_out,
        output logic valid_out,
        output logic final_out
    );

    enum  {idle, writting, adding} adder_states;


    localparam BRAM_WIDTH = register_size;
    localparam BRAM_DEPTH = bits_in_num/BRAM_WIDTH;
    localparam ADDR_WIDTH = $clog2(BRAM_DEPTH);

    logic [$clog2(BRAM_DEPTH):0] address_index;

    // only using port a for reads: we only use dout
    logic [BRAM_WIDTH-1:0]     douta;
    logic [ADDR_WIDTH-1:0]     addra;

    // only using port b for writes: we only use din
    logic [BRAM_WIDTH-1:0]     dinb;
    logic [ADDR_WIDTH-1:0]     addrb;
    logic[$clog2(BRAM_DEPTH):0] curr_count;
    logic write_on;
    logic [register_size-1:0] current_add_chunk;
    logic cur_carry;

    logic last_trigger;

    assign last_trigger =  curr_count == BRAM_DEPTH-1 && adder_states == adding;
    

    assign write_on =  (adder_states ==  writting ||adder_states == idle) && valid_in;


    localparam BRAM_CYCLE_DELAY = 2;

    pipeliner#(.PIPELINE_STAGE_COUNT(BRAM_CYCLE_DELAY), .DATA_BIT_SIZE(register_size))
    add_input_pipeline(.clk_in(clk_in),.rst_in(rst_in),.data_in(chunk_in),.data_out(current_add_chunk));

    pipeliner#(.PIPELINE_STAGE_COUNT(BRAM_CYCLE_DELAY), .DATA_BIT_SIZE(1))
    valid_out_pipeline(.clk_in(clk_in),.rst_in(rst_in),.data_in(valid_in && adder_states == adding),.data_out(valid_out));
    
    pipeliner#(.PIPELINE_STAGE_COUNT(BRAM_CYCLE_DELAY), .DATA_BIT_SIZE(1))
    final_out_pipeline(.clk_in(clk_in),.rst_in(rst_in),.data_in(last_trigger),.data_out(final_out));

    logic [register_size:0]  real_sum;
    assign real_sum = douta + current_add_chunk + cur_carry;
    assign data_out = real_sum[register_size-1:0];
    
    assign carry_out =  final_out? real_sum[register_size]: carry_out;

    logic verga_bit;
    // assign verga_bit = real_sum[register_size];
     

    always_ff @( posedge clk_in ) begin 
        if(rst_in) begin
            addra<=0;
            addrb<=0;
            curr_count <=0;
            cur_carry <=0;
        end else begin
            case (adder_states)
                idle:begin
                    cur_carry <= valid_out? real_sum[register_size]: cur_carry;
                    if (valid_in) begin
                        adder_states <= writting;
                        addrb <= 1;
                        curr_count <=1;
                    end
                    else begin end 
                end
                writting:begin
                    if (valid_in) begin
                        if (curr_count == BRAM_DEPTH -1)begin 
                            adder_states <=  adding;
                            addrb <=  0;
                            curr_count <= 0;
                            cur_carry <= 0;
                        end else begin
                            cur_carry <= valid_out? real_sum[register_size]: cur_carry;
                            adder_states <=  writting;
                            addrb <=  addrb+ 1;
                            curr_count <= curr_count+1;
                        end
                    end
                    else begin end 
                end
                adding:begin
                    cur_carry <= valid_out? real_sum[register_size]: cur_carry;
                    if (valid_in) begin
                        if (curr_count == BRAM_DEPTH -1)begin 
                            adder_states <=  idle;
                            addra <=  0;
                            curr_count <= 0;
                        end else begin
                            adder_states <=  adding;
                            addra <=  addra+ 1;
                            curr_count <= curr_count+1;
                        end
                    end
                    else begin end 
                end
                // default: // shouldn't reach here
            endcase
        end
    end



    xilinx_true_dual_port_read_first_2_clock_ram
     #(.RAM_WIDTH(BRAM_WIDTH),
       .RAM_DEPTH(BRAM_DEPTH)) adder_bram
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
        .dinb(chunk_in),
        .clkb(clk_in),
        .web(write_on), // write always
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );




   

endmodule

`default_nettype wire
