`default_nettype none
// adds to the stored number in the accumulator the number of size NUM_BITS_STORED. 
// outputs in chunks of register size bits the newly stored number (with natural overflow)
module mul_store  #(
        parameter REGISTER_SIZE = 32,
        parameter NUM_BITS_STORED = 2048,
        parameter DESIRED_SIZE = 2080
    )
    (
        input wire [REGISTER_SIZE-1:0] high_in,
        input wire [REGISTER_SIZE-1:0] low_in,
        input wire[$clog2(DESIRED_SIZE):0] start_padding,
        input wire valid_in,
        input wire rst_in,
        input wire clk_in,
        output logic [REGISTER_SIZE-1:0] data_out,
        output logic valid_out,
        output logic ready_out
    );

    logic [REGISTER_SIZE-1:0] high_in_used;
    logic [REGISTER_SIZE-1:0] low_in_used;
    logic [$clog2(DESIRED_SIZE):0] start_padding_used;
    logic valid_in_used;
    localparam MIN_PIPE_DELAY = 1;

    pipeliner#(
        .PIPELINE_STAGE_COUNT(MIN_PIPE_DELAY),
        .DATA_BIT_SIZE(REGISTER_SIZE)
    )
    pip1 (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .data_in(high_in),
        .data_out(high_in_used)
    );

    pipeliner#(
        .PIPELINE_STAGE_COUNT(MIN_PIPE_DELAY),
        .DATA_BIT_SIZE(REGISTER_SIZE)
    )
    pip2 (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .data_in(low_in),
        .data_out(low_in_used)
    );

    pipeliner#(
        .PIPELINE_STAGE_COUNT(MIN_PIPE_DELAY),
        .DATA_BIT_SIZE($clog2(DESIRED_SIZE) +1)
    )
    pip3 (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .data_in(start_padding),
        .data_out(start_padding_used)
    );


    pipeliner#(
        .PIPELINE_STAGE_COUNT(MIN_PIPE_DELAY),
        .DATA_BIT_SIZE(1)
    )
    pip4 (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .data_in(valid_in),
        .data_out(valid_in_used)
    );


    


    enum  {cleaning, idle, num_storing, start_output, continue_output, outputing} store_states;

    assign ready_out = (store_states == idle) || (store_states == num_storing) ;

    localparam BRAM_WIDTH = REGISTER_SIZE;
    //store the 2 nums + the alignment of the second one
    localparam BRAM_DEPTH = (2*DESIRED_SIZE / BRAM_WIDTH);
    localparam SECOND_OFFSET = DESIRED_SIZE / BRAM_WIDTH + 1;
    localparam ADDR_WIDTH = $clog2(BRAM_DEPTH);


    logic [BRAM_WIDTH-1:0]     douta;
    logic [ADDR_WIDTH-1:0]     addra;
    logic [ADDR_WIDTH-1:0]     addrb;



    localparam STORE_CUTOFF = DESIRED_SIZE / REGISTER_SIZE - 2;

    localparam DESIRED_STORE_COUNT = NUM_BITS_STORED / REGISTER_SIZE;

    logic [$clog2(DESIRED_STORE_COUNT):0] cur_count;

    assign data_out = douta;
     

    always_ff @( posedge clk_in ) begin 
        if (rst_in) begin
            addra <= 0;
            addrb <= 0;
            store_states <= cleaning;
            valid_out<=0;
            cur_count <=0;
        end else begin
            case (store_states)
                cleaning: begin
                    if (addrb == BRAM_DEPTH-1) begin
                        store_states <= idle;
                        addrb <= SECOND_OFFSET;
                    end else begin
                        addrb <=  addrb + 1;
                    end
                end
                idle: begin
                    if (valid_in_used) begin 
                        if ((addra + start_padding_used) == STORE_CUTOFF) begin
                            store_states <= start_output;
                        end else begin
                            addrb <=  addrb + 1 + start_padding_used;
                            addra <= addra + 1 + start_padding_used;
                            store_states <= num_storing;
                            cur_count <= 1;
                        end
                    end
                end
                num_storing: begin
                    if (valid_in_used) begin 
                        if( cur_count == DESIRED_STORE_COUNT-1) begin 
                            addrb <= 0;
                            addra <= 0;
                            store_states <= start_output;
                        end else begin
                            addrb <= addrb + 1;
                            addra <= addra + 1;
                            cur_count <= cur_count + 1;
                        end
                    end
                end
                start_output: begin
                    cur_count <= 0;
                    addra <= addra + 1;
                    store_states <= continue_output;
                    addrb <= 0;
                end
                continue_output: begin
                    addra <= addra + 1;
                    store_states <= outputing;
                    valid_out <= 1;
                end
                outputing:begin
                    //addrb will be our counter
                    if(addrb == BRAM_DEPTH -1) begin
                        addra <= 0;
                        addrb <= SECOND_OFFSET;
                        store_states <= idle;
                        valid_out <= 0;
                    end else begin
                        addra <= addra + 1;
                        addrb <= addrb + 1;
                    end
                end
                // default: // shouldn't reach here
            endcase
        end
    end

    logic write_on;
    assign write_on =  (store_states == cleaning)
                    || ((store_states == num_storing || store_states == idle) && valid_in_used)
                    || (store_states ==  outputing);

    logic [REGISTER_SIZE-1:0] b_write;
    assign b_write = (store_states == num_storing) || (store_states == idle) ? high_in_used : 0;

    logic [ADDR_WIDTH-1:0]     shifted_addra;
    assign shifted_addra = (store_states == idle) ? addra + start_padding_used: addra;

    logic [ADDR_WIDTH-1:0]     shifted_addrb;
    assign shifted_addrb = (store_states == idle) ? addrb + start_padding_used: addrb;

    xilinx_true_dual_port_read_first_2_clock_ram
     #(.RAM_WIDTH(BRAM_WIDTH),
       .RAM_DEPTH(BRAM_DEPTH)) splitter_bram
       (
        // PORT A
        .addra(shifted_addra),
        .dina(low_in_used), 
        .clka(clk_in),
        .wea(write_on && !(store_states == cleaning) && !(store_states == outputing)), 
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