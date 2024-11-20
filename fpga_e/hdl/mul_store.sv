`default_nettype none
// adds to the stored number in the accumulator the number of size num_bits_stored. 
// outputs in chunks of register size bits the newly stored number (with natural overflow)
module mul_store  #(
    parameter register_size = 32,
    parameter num_bits_stored = 2048,
    parameter desired_size = 2080
    )
    (
        input wire [register_size-1:0] high_in,
        input wire [register_size-1:0] low_in,
        input wire[$clog2(desired_size):0] start_padding,
        input wire valid_in,
        input wire rst_in,
        input wire clk_in,
        output logic [register_size-1:0] data_out,
        output logic valid_out,
        output logic ready_out
    );

    enum  {cleaning, idle, num_storing, start_output, continue_output, outputing} store_states;

    assign ready_out = store_states != cleaning;

    localparam BRAM_WIDTH = register_size;
    //store the 2 nums + the alignment of the second one
    localparam BRAM_DEPTH = (2*desired_size/BRAM_WIDTH);
    localparam SECOND_OFFSET = desired_size/BRAM_WIDTH + 1;
    localparam ADDR_WIDTH = $clog2(BRAM_DEPTH);


    logic [BRAM_WIDTH-1:0]     douta;
    logic [ADDR_WIDTH-1:0]     addra;
    logic [ADDR_WIDTH-1:0]     addrb;



    localparam STORE_CUTOFF = desired_size/register_size - 2;

    localparam DESIRED_STORE_COUNT = num_bits_stored/register_size;

    logic [$clog2(DESIRED_STORE_COUNT):0] cur_count;

    assign data_out = douta;
     

    always_ff @( posedge clk_in ) begin 
        if(rst_in) begin
            addra <= 0;
            addrb <= 0;
            store_states <= cleaning;
            valid_out<=0;
            cur_count <=0;
        end else begin
            case (store_states)
                cleaning:begin
                    if (addrb == BRAM_DEPTH-1)begin
                        store_states <= idle;
                        addrb <=  SECOND_OFFSET;
                    end else begin
                        addrb <=  addrb + 1;
                    end
                end
                idle:begin
                    if (valid_in)begin 
                        if ((addra + start_padding) == STORE_CUTOFF)begin
                            store_states <= start_output;
                        end else begin
                            addrb <=  addrb + 1 + start_padding;
                            addra <= addra + 1 + start_padding;
                            store_states <= num_storing;
                            cur_count<=1;
                        end
                    end
                end
                num_storing:begin
                    if (valid_in)begin 
                        if( cur_count == DESIRED_STORE_COUNT-1)begin 
                            addrb <=  0;
                            addra <= 0;
                            store_states <= start_output;
                        end else begin
                            addrb <=  addrb + 1;
                            addra <= addra + 1;
                            cur_count<= cur_count+1;
                        end
                    end
                end
                start_output:begin
                    cur_count<=0;
                    addra <= addra+1;
                    store_states <= continue_output;
                    addrb<=0;
                end
                continue_output:begin
                    addra <= addra+1;
                    store_states<=outputing;
                    valid_out <= 1;
                end
                outputing:begin
                    //addrb will be our counter
                    if(addrb == BRAM_DEPTH -1) begin
                        addra <= 0;
                        addrb <= SECOND_OFFSET;
                        store_states <= idle;
                        valid_out<=0;
                    end else begin
                        addra<=addra+1;
                        addrb<= addrb+1;
                    end
                end
                // default: // shouldn't reach here
            endcase
        end
    end

logic write_on;
assign write_on =  store_states ==  cleaning || ((store_states ==  num_storing || store_states ==idle) && valid_in) || store_states ==  outputing;



logic [register_size-1:0] b_write;
assign b_write = store_states == num_storing || store_states == idle ? high_in:0;

logic [ADDR_WIDTH-1:0]     shifted_addra;
assign shifted_addra = store_states == idle? addra + start_padding: addra;
logic [ADDR_WIDTH-1:0]     shifted_addrb;
assign shifted_addrb = store_states == idle? addrb + start_padding: addrb;

    xilinx_true_dual_port_read_first_2_clock_ram
     #(.RAM_WIDTH(BRAM_WIDTH),
       .RAM_DEPTH(BRAM_DEPTH)) splitter_bram
       (
        // PORT A
        .addra(shifted_addra),
        .dina(low_in), 
        .clka(clk_in),
        .wea(write_on && !(store_states ==cleaning)), 
        .ena(1'b1),
        .rsta(rst_in),
        .regcea(1'b1),
        .douta(douta),
        // PORT B
        .addrb(shifted_addrb),
        .dinb(b_write),
        .clkb(clk_in),
        .web(write_on),
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );




   

endmodule

`default_nettype wire
