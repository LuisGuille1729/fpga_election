`default_nettype none
// computes addition of 2 numbers by writing to block ram and sending the data back out in cycles
// has a valid out signal and a last signal to showcase a finished addition. 
module fsm_multiplier  #(
    parameter REGISTER_SIZE = 32,
    parameter BITS_IN_NUM = 2048
    )
    (
        input wire [REGISTER_SIZE-1:0] n_in,
        input wire [REGISTER_SIZE-1:0] m_in,
        input wire valid_in,
        input wire rst_in,
        input wire clk_in,
        output logic [REGISTER_SIZE-1:0] data_out,
        output logic valid_out,
        output logic final_out,
        output logic ready_out
    );

    enum  {idle, writing, begin_loading, middle_loading, stream_loading, waiting, outputing} mult_state;
    assign ready_out = (mult_state == idle);

    localparam BRAM_WIDTH = REGISTER_SIZE;
    // Double the depth in order to read and write twice (from two separate regions) from the same BRAM in the same cycle
    localparam BRAM_REGION_SIZE = BITS_IN_NUM / BRAM_WIDTH;
    localparam BRAM_DEPTH = 2 * BRAM_REGION_SIZE;
    localparam ADDR_WIDTH = $clog2(BRAM_DEPTH);


    // storage bram data 
    logic [BRAM_WIDTH-1:0]     douta_n;
    logic [BRAM_WIDTH-1:0]     douta_m;   
    
    //addresses to read from 2 clock cycles in future
    logic [ADDR_WIDTH-1:0]     addra_m;
    logic [ADDR_WIDTH-1:0]     addra_n;

    logic [ADDR_WIDTH-1:0]     cur_count;
    logic [ADDR_WIDTH +1:0]   send_count;



    logic[2*REGISTER_SIZE-1:0] chunk_multiplication;

    assign chunk_multiplication = douta_n * douta_m;

    logic[$clog2(BITS_IN_NUM)-1:0] store_shift;



     
    // Multiplier logic
    always_ff @( posedge clk_in ) begin 
        if(rst_in) begin
            addra_n <= 0;
            addra_m <= 0;

            mult_state <= idle;
        end else begin
            case (mult_state)
                idle: begin
                    send_count <=0;
                    store_shift <= 0;
                    if (valid_in) begin
                        mult_state <= writing;
                        
                        addra_n <= 1;
                        addra_m <= 1;
                    end
                end
                writing: begin
                    if (valid_in) begin
                        if (addra_n == BRAM_REGION_SIZE-1) begin
                            mult_state <= begin_loading;

                            addra_m <= 0;  // Wrap-around the writing positions (like a ring)
                            addra_n <= 0;
                        end else begin
                            addra_n <= addra_n + 1;
                            addra_m <= addra_m + 1; 
                        end
                    end
                end

                // We are multiplying n by m (i.e. we keep each chunk of m fixed per iteration)
                // We also assume they come here aligned as should be
                begin_loading: begin
                    // Cleaning accumulator bram may take longer than expected
                    if (store_ready) begin
                        mult_state <= middle_loading;
                        addra_n <= 1;         
                    end
                end

                middle_loading: begin
                    mult_state <= stream_loading;
                    addra_n <= 2;
                    cur_count <= 0;
                end

                stream_loading: begin
                    addra_n <= addra_n + 1;
                    //addra_n is 2 in front of b
                    if (cur_count == BRAM_REGION_SIZE-1) begin
                        mult_state <= (addra_m == BRAM_REGION_SIZE-1) ? outputing : waiting;
                    end else begin
                        cur_count <= cur_count + 1;
                    end
                end

                waiting: begin
                    // only want to update once
                    addra_m <= cur_count != 0 ? addra_m + 1 : addra_m;
                    addra_n <= 0;
                    cur_count <= 0;
                    mult_state <= store_ready ? begin_loading : waiting;
                    store_shift <= (cur_count != 0) ? store_shift + 1 : store_shift;
                end
                outputing: begin
                    // only want to update once
                    send_count <= send_count + accum_valid;
                    addra_m <= 0;
                    addra_n <= 0;
                    store_shift <= 0;
                    cur_count <= 0;
                    // mult_state <= store_ready? idle: outputing;
                    mult_state <= (send_count == 4*BRAM_REGION_SIZE - 1) ? idle : outputing;
                end
                // default: // shouldn't reach here
            endcase
        end
    end

    logic [REGISTER_SIZE-1:0] high_in;
    assign high_in = chunk_multiplication[2*REGISTER_SIZE - 1:REGISTER_SIZE];

    logic [REGISTER_SIZE-1:0] low_in;
    assign low_in = chunk_multiplication[REGISTER_SIZE-1:0];
   
    logic mul_store_valid;
    assign mul_store_valid = (mult_state == stream_loading);

    logic [REGISTER_SIZE-1:0] store_out;
    logic store_valid;
    logic store_ready;
    mul_store  #(
        .REGISTER_SIZE(REGISTER_SIZE),
        .NUM_BITS_STORED(BITS_IN_NUM),
        .DESIRED_SIZE (2*BITS_IN_NUM)
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
        .REGISTER_SIZE(REGISTER_SIZE),
        .NUM_BITS_STORED(2*BITS_IN_NUM)
    )
    prod_accumulator
    (
        .block_in(store_out),
        .valid_in(store_valid),
        .rst_in(rst_in || mult_state == idle),
        .clk_in(clk_in),
        .data_out(data_out),
        .valid_out(accum_valid),
        .ready_out(accum_ready)
    );

    assign valid_out = accum_valid && mult_state == outputing && send_count > 2*BRAM_REGION_SIZE-1;

    logic write_on;
    assign write_on = (mult_state == idle || mult_state == writing) && valid_in;
    xilinx_true_dual_port_read_first_2_clock_ram
     #(
        .RAM_WIDTH(BRAM_WIDTH),
        .RAM_DEPTH(BRAM_DEPTH)) m_bram
       (
        // PORT A
        .addra(addra_m),
        .dina(n_in),
        .clka(clk_in),
        .wea(write_on),
        .ena(1'b1),
        .rsta(rst_in),
        .regcea(1'b1),
        .douta(douta_m),
        // PORT B
        .addrb(addra_n + BRAM_REGION_SIZE),
        .dinb(m_in),
        .clkb(clk_in),
        .web(write_on), 
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb(douta_n) // we only use port B for writes!
        );
endmodule
`default_nettype wire