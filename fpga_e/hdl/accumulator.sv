`default_nettype none
// adds to the stored number in the accumulator the number of size num_bits_stored. 
// outputs in chunks of register size bits the newly stored number (with natural overflow)
module accumulator  #(
    parameter register_size = 32,
    parameter num_bits_stored = 2048
    )
    (
        input wire [register_size-1:0] block_in,
        input wire valid_in,
        input wire rst_in,
        input wire clk_in,
        output logic [register_size-1:0] data_out,
        output logic valid_out,
        output logic ready_out
    );

    enum  {cleaning, adding} accum_states;


    localparam BRAM_WIDTH = register_size;
    localparam BRAM_DEPTH = num_bits_stored/BRAM_WIDTH;
    localparam ADDR_WIDTH = $clog2(BRAM_DEPTH);


    // only using port a for reads: we only use dout
    logic [BRAM_WIDTH-1:0]     douta;
    logic [ADDR_WIDTH-1:0]     addra;

    // only using port b for writes: we only use din
    logic [ADDR_WIDTH-1:0]     addrb;
    logic write_on;
    logic [register_size-1:0] current_add_chunk;
    logic cur_carry;

    assign ready_out = accum_states == adding;
    

    assign write_on = (accum_states ==  cleaning) || (accum_states ==  adding && valid_out);


    localparam BRAM_CYCLE_DELAY = 2;

    pipeliner#(.PIPELINE_STAGE_COUNT(BRAM_CYCLE_DELAY), .DATA_BIT_SIZE(register_size))
    add_input_pipeline(.clk_in(clk_in),.rst_in(rst_in),.data_in(block_in),.data_out(current_add_chunk));

    pipeliner#(.PIPELINE_STAGE_COUNT(BRAM_CYCLE_DELAY), .DATA_BIT_SIZE(1))
    valid_out_pipeline(.clk_in(clk_in),.rst_in(rst_in),.data_in(valid_in && accum_states == adding),.data_out(valid_out));
    

    logic [register_size:0]  real_sum;
    assign real_sum = douta + current_add_chunk + cur_carry;
    assign data_out = real_sum[register_size-1:0];
     

    always_ff @( posedge clk_in ) begin 
        if(rst_in) begin
            addra<=0;
            addrb<=0;
            cur_carry <=0;
            accum_states <= cleaning;
        end else begin
            case (accum_states)
                cleaning:begin
                if (addrb == BRAM_DEPTH -1)begin 
                    accum_states <=  adding;
                    addrb <=  0;
                    cur_carry <= 0;
                end else begin
                    addrb <=  addrb + 1;
                end 
                end
                adding:begin
                    if (valid_out)begin
                        cur_carry <= addrb == BRAM_DEPTH-1? 0: real_sum[register_size];
                        addrb <= addrb == BRAM_DEPTH-1? 0: addrb+1;
                    end 
                    if (valid_in) begin
                        if (addra == BRAM_DEPTH -1)begin 
                            addra <=  0;
                        end else begin
                            addra <=  addra+ 1;
                        end
                    end
                    else begin end 
                end
                // default: // shouldn't reach here
            endcase
        end
    end

logic [register_size-1:0] write_data;
assign write_data = accum_states == cleaning? 0: real_sum[register_size-1:0];

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
        .dinb(write_data),
        .clkb(clk_in),
        .web(write_on),
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );




   

endmodule

`default_nettype wire