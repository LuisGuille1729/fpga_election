`default_nettype none

// Efficiently calculates T(R^-1) mod N
module mont_accumulator #(
    parameter REGISTER_SIZE = 32,
    parameter BITS_IN_NUM = 4096,
    parameter R = 4096
) (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,
    input wire  n_bit_in,   
    input wire [REGISTER_SIZE-1:0] n_squared_in,
    input wire [REGISTER_SIZE-1:0] k_in,
    input wire [REGISTER_SIZE-1:0] squarer_streamer_in, 
    output logic valid_out,
    output logic[REGISTER_SIZE-1:0] data_out,
    output logic consumed_n_out,
    output logic consumed_k_out,
    output logic consumed_n_squared_out,
    output logic[REGISTER_SIZE-1:0] mult_out,
    output logic mult_valid,
    output logic[50:0] cycles_between_sends // setting for testing purposes 
);
    enum  {start,pre_cleaning,cleaning, idle, first_accum, other_acum,outputing} accum_state; 

    assign mult_out = mul_out;
    assign mult_valid = mul_valid_out;
    localparam BRAM_WIDTH = REGISTER_SIZE;
    // Double the depth in order to read and write twice (from two separate regions) from the same BRAM in the same cycle
    localparam BRAM_DEPTH = BITS_IN_NUM / BRAM_WIDTH;
    localparam ADDR_WIDTH = $clog2(BRAM_DEPTH);

    localparam BLOCKS_TO_SEND = BITS_IN_NUM / REGISTER_SIZE;
    localparam NUM_BLOCKS = 2*BITS_IN_NUM / REGISTER_SIZE;
    localparam BITS_IN_N = 2048;   
    logic [REGISTER_SIZE-1:0] visual_dif;
    assign visual_dif = a_in-b_in;
    logic b_is_input;
    assign b_is_input = b_in == squarer_streamer_in;
    
    //addresses to read from 2 clock cycles in future
    logic [ADDR_WIDTH-1:0]     addra;
    logic [BRAM_WIDTH-1:0]     douta;

    logic [REGISTER_SIZE-1:0] mul_out;
    logic mul_valid_out;
    logic [REGISTER_SIZE-1:0] a_in;
    logic [REGISTER_SIZE-1:0] b_in;
    // logic for selecting first input to multiplier
    always_comb begin 
        if (accum_state == idle || accum_state == first_accum) begin
            case (store_idx)
                0: a_in = r_0;
                1: a_in = r_1;
                default: a_in = douta; 
            endcase
        end else begin
            a_in = data_out;
        end      
    end
    //logic for selecting second input for multiplier (wrt streamer inputs)
    always_comb begin 
        if (accum_state == idle || accum_state == first_accum || n_bit_in) begin
            b_in = squarer_streamer_in; 
        end else begin
             case (store_idx)
                0: b_in = r_0;
                1: b_in = r_1;
                default: b_in = douta; 
            endcase
        end      
    end
    fsm_multiplier_parallel#(
        .REGISTER_SIZE_IN(REGISTER_SIZE),
        .BITS_IN_NUM(BITS_IN_NUM)
    )
    markiplier // iron lung?
    (
        .n_in(a_in),
        .m_in(b_in),
        .valid_in(valid_in),
        .rst_in(rst_in),
        .clk_in(clk_in),
        .data_out(mul_out),
        .valid_out(mul_valid_out),
        .final_out(),
        .ready_out()
    );

    logic mont_valid;

    montgomery_reduce_parallel#(
        .REGISTER_SIZE(REGISTER_SIZE),
        .NUM_BLOCKS(NUM_BLOCKS),
        .R(4096)
    ) monty_gatorade (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .valid_in(mul_valid_out),
        .T_block_in(mul_out),   // the number we want to reduce
        
        .k_constant_block_in(k_in), 
        .consumed_k_out(consumed_k_out),
        
        .modN_constant_block_in(n_squared_in),
        .consumed_N_out(consumed_n_squared_out),
        .valid_out(mont_valid),
        .data_block_out(data_out)
    );

    assign valid_out = accum_state == outputing && mont_valid;

    logic [REGISTER_SIZE-1:0] r_0;
    logic [REGISTER_SIZE-1:0] r_1;
    logic final_cleaning;
    logic[$clog2(NUM_BLOCKS)-1:0] store_idx;
    logic[$clog2(BITS_IN_N)-1:0] cycle_idx;

    always_ff @( posedge clk_in ) begin
        if (rst_in)begin
            accum_state <= start;
            consumed_n_out <=0;
            addra <=0;
            cycles_between_sends<=0;
        end
        case (accum_state)
            start:begin
                consumed_n_out<=0;
                cycle_idx<=0;
                store_idx<=0;
                accum_state <=pre_cleaning;
                addra <=1;
                final_cleaning <=0;
            end
            pre_cleaning: begin
                accum_state <= cleaning;
                addra <= 2;
            end
            cleaning: begin
                final_cleaning <= ~final_cleaning;
                r_1 <= douta;
                if (final_cleaning) begin
                    accum_state <= idle;
                end  else begin
                    r_0 <= douta;
                end
            end

            idle: begin
                if (valid_in) begin
                    cycles_between_sends<=1;
                    accum_state <= first_accum;
                    store_idx <= store_idx + 1;
                end 
                consumed_n_out <= 0;
                addra <= addra + 1;
            end
            first_accum: begin
                if (valid_in) begin
                    if (store_idx == BLOCKS_TO_SEND-1) begin
                        accum_state <= other_acum;
                        store_idx <=0;
                        cycle_idx <= 1;
                        consumed_n_out <= 1;
                        addra <= 2;
                    end else begin
                        store_idx <= store_idx +1;
                        addra <= addra + 1;
                    end
                    cycles_between_sends<=0;
                end
            end
            other_acum: begin
                if (mont_valid) begin
                    cycles_between_sends<=0;
                    if (store_idx == BLOCKS_TO_SEND - 1) begin
                        accum_state <= cycle_idx ==  BITS_IN_N-1? outputing: other_acum;
                        store_idx <= 0;
                        consumed_n_out <= 1;
                        cycle_idx <= cycle_idx +1;
                        addra <= 2;
                    end else begin
                        store_idx <= store_idx + 1;
                        consumed_n_out <= 0;
                        addra <= addra + 1; 
                    end
                end else begin
                   consumed_n_out <= 0; 
                   cycles_between_sends<=cycles_between_sends+1;
                end
            end

            outputing: begin
                consumed_n_out<=0;
                if (mont_valid) begin
                    if (store_idx == BLOCKS_TO_SEND - 1) begin
                        accum_state <= idle;
                        store_idx <= 0;
                        cycle_idx <= 0;
                        addra <= 2;
                    end else begin
                        store_idx <= store_idx + 1;
                    end
                end
                   consumed_n_out <= 0; 
            end
        endcase


    end


xilinx_true_dual_port_read_first_2_clock_ram
     #(.RAM_WIDTH(BRAM_WIDTH),
       .RAM_DEPTH(BRAM_DEPTH)
       ,
       .INIT_FILE("../../data/R_modN.mem")       
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
        .addrb(),
        .dinb(),
        .clkb(clk_in),
        .web(0),
        .enb(0),
        .rstb(rst_in),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );



endmodule

`default_nettype wire