`default_nettype none

// Efficiently calculates T(R^-1) mod N
`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */
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
    output logic[50:0] cycles_between_sends, // setting for testing purposes
    output logic mont_valid_out,
    output logic [REGISTER_SIZE-1:0] annoy_signal,

    output logic [REGISTER_SIZE-1:0] r_0,
    output logic [REGISTER_SIZE-1:0] r_1


);
    assign mont_valid_out = mont_valid;
    enum  {start,stage1,stage2,stage3, first_accum, other_accums} accum_state; 

    logic prev_valid;



    localparam BRAM_WIDTH = REGISTER_SIZE;
    // Double the depth in order to read and write twice (from two separate regions) from the same BRAM in the same cycle
    localparam BRAM_DEPTH = BITS_IN_NUM / BRAM_WIDTH;
    localparam ADDR_WIDTH = $clog2(BRAM_DEPTH);

    localparam BLOCKS_TO_SEND = BITS_IN_NUM / REGISTER_SIZE;
    localparam NUM_BLOCKS = 2*BITS_IN_NUM / REGISTER_SIZE;
    localparam BITS_IN_N = 2048;   
    
    //addresses to read from 2 clock cycles in future
    logic [ADDR_WIDTH-1:0]     addra;
    logic [BRAM_WIDTH-1:0]     douta;
    logic [REGISTER_SIZE-1:0] a_in;
    logic [REGISTER_SIZE-1:0] b_in;
    // logic for selecting first input to multiplier

    logic hard_reset;
    assign hard_reset =  rst_in || (prev_valid && !valid_out);
    always_comb begin 
        if (accum_state == first_accum) begin
            case (addra)
                2: a_in = r_0;
                3: a_in = r_1;
                default: a_in = douta; 
            endcase
        end else begin
            a_in = data_out;
        end      
    end
    //logic for selecting second input for multiplier (wrt streamer inputs)
    always_comb begin 
        if (accum_state == first_accum || n_bit_in) begin
            b_in = squarer_streamer_in; 
        end else begin
             case (addra)
                2: b_in = r_0;
                3: b_in = r_1;
                default: b_in = douta; 
            endcase
        end      
    end
    // logic[$clog2(NUM_BLOCKS)-1:0] store_idx;
    logic[$clog2(BITS_IN_N)-1:0] cycle_idx;
    always_ff @( posedge clk_in ) begin

        if (hard_reset)begin
            accum_state<= start; 
            addra<=0;
            consumed_n_out<=0;
            cycle_idx<=0;
            prev_valid<=0;
        end else begin
            prev_valid<= valid_out;
            case (accum_state)
                start : begin
                    addra<=1;
                    accum_state<= stage1;
                end 
                stage1 : begin
                    addra<=2;
                    accum_state<= stage2;
                end
                stage2 : begin
                    addra<=2;
                    accum_state<= stage3;
                    r_0<=douta;
                end
                stage3: begin
                    addra<=2;
                    accum_state<= first_accum;
                    r_1<=douta;
                end
                first_accum: begin
                    if (valid_in) begin
                        if (addra == 1) begin
                            accum_state <= other_accums;
                            cycle_idx <= cycle_idx + 1;
                            consumed_n_out<=1;
                        end else begin
                            consumed_n_out<=0;
                        end
                        addra <= addra == BRAM_DEPTH-1? 0: addra+1;
                    end else begin
                            consumed_n_out<=0;
                        end
                end
                other_accums: begin
                    if (mont_valid) begin
                        if (addra == 1) begin
                            accum_state<= cycle_idx == BITS_IN_N-1? first_accum: other_accums;
                            cycle_idx<= cycle_idx == BITS_IN_N-1?0:cycle_idx + 1;
                            consumed_n_out<=1;
                        end else begin
                            consumed_n_out<=0;
                        end
                        addra <= addra == BRAM_DEPTH-1? 0: addra+1;
                    end else begin
                            consumed_n_out<=0;
                        end
                end
            endcase
        end
    end


    logic [REGISTER_SIZE-1:0] mul_out;
    logic mul_valid_out;

    fsm_multiplier#(
        .REGISTER_SIZE(REGISTER_SIZE),
        .BITS_IN_NUM(BITS_IN_NUM)
    )
    markiplier // iron lung?
    (
        .n_in(a_in),
        .m_in(b_in),
        .valid_in(valid_in),
        .rst_in(hard_reset),
        .clk_in(clk_in),
        .data_out(mul_out),
        .valid_out(mul_valid_out),
        .final_out(),
        .ready_out()
    );

    logic mont_valid;

    montgomery_reduce#(
        .REGISTER_SIZE(REGISTER_SIZE),
        .NUM_BLOCKS(NUM_BLOCKS),
        .R(R)
    ) monty_gatorade (
        .clk_in(clk_in),
        .rst_in(hard_reset),
        .valid_in(mul_valid_out),
        .T_block_in(mul_out),   // the number we want to reduce
        
        .k_constant_block_in(k_in), 
        .consumed_k_out(consumed_k_out),
        
        .modN_constant_block_in(n_squared_in),
        .consumed_N_out(consumed_n_squared_out),
        .valid_out(mont_valid),
        .data_block_out(data_out)
    );

    assign valid_out = accum_state == first_accum && mont_valid;


xilinx_true_dual_port_read_first_2_clock_ram
     #(.RAM_WIDTH(BRAM_WIDTH),
       .RAM_DEPTH(BRAM_DEPTH),
       .INIT_FILE(`FPATH(R_modN.mem))       
       ) const_storage_bram
       (
        // PORT A
        .addra(addra),
        .dina(0), // we only use port A for reads!
        .clka(clk_in),
        .wea(0), // read only
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