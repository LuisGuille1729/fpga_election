`default_nettype none
// computes addition of 2 numbers by writting to block ram and sending the data back out in cycles
// has a valid out signal and a last signal to showcase a finished addition. 
module fsm_multiplier  #(
    parameter register_size = 32,
    parameter bits_in_num = 2048
    )
    (
        input wire [register_size-1:0] n_in,
        input wire [register_size-1:0] m_in,
        input wire valid_in,
        input wire rst_in,
        input wire clk_in,
        output logic [register_size-1:0] data_out,
        output logic valid_out,
        output logic final_out,
        output logic ready_out
    );

    enum  {idle, writting,begin_loading, middle_loading, stream_loading, waiting, outputing} mult_states;
    assign ready_out = mult_states == idle;

    localparam BRAM_WIDTH = register_size;
    localparam BRAM_DEPTH = bits_in_num/BRAM_WIDTH;
    localparam ADDR_WIDTH = $clog2(BRAM_DEPTH);


    // storage bram data 
    logic [BRAM_WIDTH-1:0]     douta_n;
    logic [BRAM_WIDTH-1:0]     douta_m;   
    
    //addresses to read from 2 clock cycles in future
    logic [ADDR_WIDTH-1:0]     addra_m;
    logic [ADDR_WIDTH-1:0]     addra_n;

    //addresses to write to 2 clock cycles in the future
    logic [ADDR_WIDTH-1:0]     addrb_m;
    logic [ADDR_WIDTH-1:0]     addrb_n;

    logic [ADDR_WIDTH-1:0]     cur_count;
    logic [ADDR_WIDTH +1:0]   send_count;



    logic[2*register_size-1:0] chunk_mutliplication;

    assign chunk_mutliplication = douta_n * douta_m;

    logic[$clog2(bits_in_num)-1:0] store_shift;



     

    always_ff @( posedge clk_in ) begin 
        if(rst_in) begin
            addra_n <=0;
            addra_m <=0;

            addrb_n <=0;
            addrb_m <=0;
            mult_states <=idle;
        end else begin

            case (mult_states)
                idle:begin
                    send_count <=0;
                    store_shift<=0;
                    if (valid_in) begin
                        mult_states <= writting;
                         
                        addrb_n <= 1;
                        addrb_m <= 1;
                        
                        addra_n <= 0;
                        addra_m <= 0;
                    end
                end
                writting:begin
                    if (valid_in) begin
                        if (addrb_n == BRAM_DEPTH-1) begin 
                            mult_states <= begin_loading;
                            //reset writting positions:
                            addrb_m<=0;
                            addrb_n <=0;
                        end else begin
                            addrb_n <=  addrb_n + 1;
                            addrb_m <=  addrb_m + 1; 
                        end
                    end
                end

// we are multiplying n by m (ie we keep each chunk of m fixed per iteration)
// we also asusume they come here aligned as should be
                begin_loading:begin
                    // cleaning accumulator bram may take longer than expected
                    if (store_ready)begin
                        mult_states <= middle_loading;
                        addra_n <=1;         
                    end
                end

                middle_loading: begin
                    mult_states<=stream_loading;
                    addra_n <= 2;
                    cur_count <=0;  
                end

                stream_loading: begin
                    addra_n <= addra_n +1;  
                    //addra_n is 2 in front of b
                    if (cur_count == BRAM_DEPTH-1) begin
                        mult_states <= addra_m ==  BRAM_DEPTH-1? outputing: waiting;
                    end else begin
                        cur_count <= cur_count +1;
                    end
                end

                waiting:begin
                    // only want to update once
                    addra_m <= cur_count !=0? addra_m +1 : addra_m;
                    addra_n <= 0;
                    cur_count <=0;
                    mult_states <= store_ready? begin_loading: waiting;
                    store_shift <= cur_count !=0? store_shift + 1 : store_shift;
                end
                outputing :begin
                    // only want to update once
                    send_count <= send_count + accum_valid;
                    addra_m <= 0;
                    addra_n <=0;
                    store_shift<=0;
                    cur_count <=0;
                    // mult_states <= store_ready? idle: outputing;
                    mult_states <= send_count == 4*BRAM_DEPTH-1? idle:outputing;
                end
                

                // default: // shouldn't reach here
            endcase
        end
    end

    logic [register_size-1:0] high_in;
    assign high_in = chunk_mutliplication[2*register_size-1:register_size];

    logic [register_size-1:0] low_in;
    assign low_in = chunk_mutliplication[register_size-1:0];
   
    logic mul_store_valid;
    assign mul_store_valid = mult_states == stream_loading;

    logic [register_size-1:0] store_out;
    logic store_valid;
    logic store_ready;
    mul_store  #(
    .register_size(register_size),
    .num_bits_stored(bits_in_num),
    .desired_size (2*bits_in_num)
    )
    mul_storer
    (
        .high_in(high_in),
        .low_in(low_in),
        .start_padding(store_shift),
        .valid_in(mul_store_valid),
        .rst_in(rst_in),
        .clk_in(clk_in),
        .data_out(store_out),
        .valid_out(store_valid),
        .ready_out(store_ready)
    );

    logic accum_valid;
    logic accum_ready;

    accumulator  #(
    .register_size(register_size),
    .num_bits_stored(2*bits_in_num)
    )
    prod_accumulator
    (
        .block_in(store_out),
        .valid_in(store_valid),
        .rst_in(rst_in || mult_states == idle),
        .clk_in(clk_in),
        .data_out(data_out),
        .valid_out(accum_valid),
        .ready_out(accum_ready)
    );

    assign valid_out = accum_valid && mult_states == outputing && send_count > 2*BRAM_DEPTH-1;




    logic write_on;
    assign write_on = (mult_states == idle || mult_states == writting) && valid_in;
    xilinx_true_dual_port_read_first_2_clock_ram
     #(.RAM_WIDTH(BRAM_WIDTH),
       .RAM_DEPTH(BRAM_DEPTH)) m_bram
       (
        // PORT A
        .addra(addra_m),
        .dina(0), // we only use port A for reads!
        .clka(clk_in),
        .wea(1'b0), // read only
        .ena(1'b1),
        .rsta(rst_in),
        .regcea(1'b1),
        .douta(douta_m),
        // PORT B
        .addrb(addrb_m),
        .dinb(m_in),
        .clkb(clk_in),
        .web(write_on), 
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );


xilinx_true_dual_port_read_first_2_clock_ram
     #(.RAM_WIDTH(BRAM_WIDTH),
       .RAM_DEPTH(BRAM_DEPTH)) n_bram
       (
        // PORT A
        .addra(addra_n),
        .dina(0), // we only use port A for reads!
        .clka(clk_in),
        .wea(1'b0), // read only
        .ena(1'b1),
        .rsta(rst_in),
        .regcea(1'b1),
        .douta(douta_n),
        // PORT B
        .addrb(addrb_n),
        .dinb(n_in),
        .clkb(clk_in),
        .web(write_on), 
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );



   

endmodule

`default_nettype wire
