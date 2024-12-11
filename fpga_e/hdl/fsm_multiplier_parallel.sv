`default_nettype none
// computes addition of 2 numbers by writing to block ram and sending the data back out in cycles
// has a valid out signal and a last signal to showcase a finished addition. 
module fsm_multiplier_parallel  #(
    parameter REGISTER_SIZE_IN = 32,
    parameter BITS_IN_NUM = 4096
    )
    (
        input wire [REGISTER_SIZE_IN-1:0] n_in,
        input wire [REGISTER_SIZE_IN-1:0] m_in,
        input wire valid_in,
        input wire rst_in,
        input wire clk_in,
        output logic [REGISTER_SIZE_IN-1:0] data_out,
        output logic valid_out,
        output logic final_out,
        output logic ready_out
    );

    localparam REGISTER_SIZE = REGISTER_SIZE_IN*2;
    localparam BRAM_WIDTH = REGISTER_SIZE;
    localparam BRAM_REGION_SIZE = BITS_IN_NUM / BRAM_WIDTH; // 4096/32 = 128
    localparam BRAM_DEPTH = 2 * BRAM_REGION_SIZE;   // Twice since product can double amount of bits
    localparam ADDR_WIDTH = $clog2(BRAM_DEPTH);

    enum bit[1:0] {IDLE, WRITING, COMPUTING, OUTPUTING} state;

    //****** BRAM TO STORE N AND M *******//

    // Port A
    logic [ADDR_WIDTH-1:0] n_m_bram_A_addr;
    logic [BRAM_WIDTH-1:0] n_m_bram_A_write_data_block;
    logic [BRAM_WIDTH-1:0] n_m_bram_A_read_data_block;
    logic [BRAM_WIDTH-1:0] n_m_bram_A_read_data_block_true_value;
    // artificially make 0 for A_address 128 (2 cycle delay, so this happens when addr = 0)
    assign n_m_bram_A_read_data_block = (n_m_bram_A_addr == 1) ? 0 : n_m_bram_A_read_data_block_true_value;

    // Port B
    logic [ADDR_WIDTH-1:0] n_m_bram_B_addr;
    logic [BRAM_WIDTH-1:0] n_m_bram_B_write_data_block;
    logic [BRAM_WIDTH-1:0] n_m_bram_B_read_data_block;

    xilinx_true_dual_port_read_first_2_clock_ram
    #(
        .RAM_WIDTH(REGISTER_SIZE),
        .RAM_DEPTH(BRAM_DEPTH))
    n_m_bram
        (
        // PORT A - store n
        .addra(n_m_bram_A_addr),
        .dina(n_m_bram_A_write_data_block),
        .clka(clk_in),
        .wea(state == WRITING), 
        .ena(1'b1),
        .rsta(rst_in),
        .regcea(state == COMPUTING), // read when computing
        .douta(n_m_bram_A_read_data_block_true_value),
        // PORT B - store m
        .addrb(n_m_bram_B_addr),
        .dinb(n_m_bram_B_write_data_block),
        .clkb(clk_in),
        .web(state == WRITING), 
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(state == COMPUTING),
        .doutb(n_m_bram_B_read_data_block) 
    );

    //****** BRAM TO STORE RESULT ACCUMULATOR *******//

    // Port A - WRITE ONLY
    logic [ADDR_WIDTH-1:0] accumulator_bram_A_write_addr;
    logic [BRAM_WIDTH-1:0] accumulator_bram_A_write_data_block;

    // Port B - READ ONLY
    logic [ADDR_WIDTH-1:0] accumulator_bram_B_read_addr;
    logic [BRAM_WIDTH-1:0] accumulator_bram_B_read_data_block;
    logic [BRAM_WIDTH-1:0] accumulator_bram_B_read_data_block_piped;
    always_ff @( posedge clk_in ) begin
        accumulator_bram_B_read_data_block_piped <= (rst_in) ? 0 : accumulator_bram_B_read_data_block;
    end

    logic [ADDR_WIDTH-1:0] accumulator_addr_pipe1;
    logic [ADDR_WIDTH-1:0] accumulator_addr_pipe2;
    logic [ADDR_WIDTH-1:0] accumulator_addr_pipe3;

    xilinx_true_dual_port_read_first_2_clock_ram
    #(
        .RAM_WIDTH(REGISTER_SIZE),
        .RAM_DEPTH(BRAM_DEPTH))
    accumulator_bram
        (
        // PORT A - WRITE ONLY
        .addra(accumulator_bram_A_write_addr),    // make it equal to pipe2 of n_m_A_addr + n_m_B_addr
        .dina(accumulator_bram_A_write_data_block),
        .clka(clk_in),
        .wea(state != IDLE), // always write when valid writing
        .ena(1'b1),
        .rsta(rst_in),
        .regcea(1'b0), // disable reading
        .douta(),
        // PORT B - READ ONLY
        .addrb(accumulator_bram_B_read_addr),    // make it equal to n_m_A_addr + n_m_B_addr
        .dinb(),
        .clkb(clk_in),
        .web(1'b0), // disable writing 
        .enb(1'b1),
        .rstb(rst_in),
        .regceb(1'b1), // always read
        .doutb(accumulator_bram_B_read_data_block) 
    );


    //****** MULTIPLIER FSM LOGIC *******//
    // See multiplier2048_demo.py for a python implementation
    // 1. On valid_in on IDLE, go to WRITING:
    //      - Write n and m into the bram
    // 2. Once done writing, go to COMPUTING:
    //      - compute A*B a block at a time, divide into lower_AB_block, upper_AB_block
    //      - add lower_AB_block + previous_upper_AB_block + previous_AB_carry (current_sum_block)
    //      - add current_sum_block + running_accumulator_block + running_accumulator_carry
    //          - store this value in the accumulator
    //      - continue until gone through all B, but do one more time with 0 block (to add any remaining data)
    //  3. Go to OUTPUTING and send the values in the accumulator.
    //      - Simulatneously cleans the accumulator
    //      - Go back to IDLE
    //
    //  In theory, this should take:
    //      1. 128 +2 cycles to store n and m
    //      2. ~128*129  = ~16,512 cycles to compute (a few more)
    //      3. 256 +2 cycles to output result 
    //  Expected total: 16,900 cycles
    //
    logic n_m_reading_valid;
    logic n_m_reading_valid_pipe1;
    logic n_m_reading_valid_pipe2;
    logic n_m_reading_valid_pipe3;

    logic block_loaded;
    logic [REGISTER_SIZE_IN-1:0] last_n_block_in;
    logic [REGISTER_SIZE_IN-1:0] last_m_block_in;
    assign n_m_bram_A_write_data_block = (n_in << REGISTER_SIZE_IN) | last_n_block_in;
    assign n_m_bram_B_write_data_block = (m_in << REGISTER_SIZE_IN) | last_m_block_in; 
    logic finalize_writing_next_cycle;
    logic computing_done;
    logic computing_done_pipe1;
    logic computing_done_pipe2;
    logic computing_done_pipe3;
    logic computing_done_pipe4;


    always_ff @( posedge clk_in ) begin
        
        if (rst_in || (!valid_in && state == IDLE)) begin
            state <= IDLE;
            n_m_bram_A_addr <= 0;
            // n_m_bram_A_write_data_block <= 0;
            n_m_bram_B_addr <= BRAM_REGION_SIZE;    // start at 128
            // n_m_bram_B_write_data_block <= 0;
            
            n_m_reading_valid <= 0;
            n_m_reading_valid_pipe1 <= 0;
            n_m_reading_valid_pipe2 <= 0;
            n_m_reading_valid_pipe3 <= 0;

            valid_product <= 0;
            prev_upper_prod <= 0;
            prev_prod_sum_carry <= 0;
            prev_accumulator_sum_carry <= 0;

            accumulator_addr_pipe1 <= 0;
            accumulator_addr_pipe2 <= 0;
            accumulator_addr_pipe3 <= 0;
            accumulator_bram_A_write_addr <= BRAM_REGION_SIZE;
            accumulator_bram_A_write_data_block <= 0;
            accumulator_bram_B_read_addr <= 0;

            final_pipe1 <= 1'b0;
            final_pipe2 <= 1'b0;
            final_out <= 1'b0;

            block_loaded <= 1'b0;
            last_m_block_in <= 0;
            last_n_block_in <= 0;
            bab_z0 <= 0;
            bab_z1_a <= 0;
            bab_z1_b <= 0;
            bab_z2 <= 0;
            finalize_writing_next_cycle <= 0;
            computing_done <= 0;
            computing_done_pipe1 <= 0;
            computing_done_pipe2 <= 0;
            computing_done_pipe3 <= 0;
            computing_done_pipe4 <= 0;

        end else begin

            case (state)
                IDLE: begin
                    // Start it all
                    if (valid_in) begin
                        state <= WRITING;

                        
                        // n_m_bram_A_write_data_block <= n_in; // do this combinationally instead
                        // n_m_bram_B_write_data_block <= m_in;
                        last_n_block_in <= n_in;
                        last_m_block_in <= m_in;
                        block_loaded <= 1'b1;

                    end
                end
                WRITING: begin
                    // Write n and m into BRAM
                    if (finalize_writing_next_cycle) begin
                        state <= COMPUTING;

                        n_m_bram_A_addr <= 0;
                        n_m_bram_B_addr <= BRAM_REGION_SIZE;    // start at 128

                        n_m_reading_valid <= 1;

                        accumulator_bram_A_write_addr <= 0;
                        block_loaded <= 1'b0;
                    end
                    else if (valid_in) begin
                    block_loaded <= !block_loaded;

                    last_n_block_in <= n_in;
                    last_m_block_in <= m_in;


                    n_m_bram_A_addr <= (block_loaded) ? n_m_bram_A_addr + 1 : n_m_bram_A_addr; // write to next address if got the previous blocks
                    // n_m_bram_A_write_data_block <= n_in; // do this combinationally instead

                    n_m_bram_B_addr <= (block_loaded) ? n_m_bram_B_addr + 1 : n_m_bram_B_addr; // write to next address if got the previous blocks
                    // n_m_bram_B_write_data_block <= m_in;  // do this combinationally instead

                    // Clean top BRAM
                    accumulator_bram_A_write_addr <= accumulator_bram_A_write_addr + 1;
                    accumulator_bram_A_write_data_block <= 0;

                    end

                    // End writing
                    if (n_m_bram_A_addr == (BRAM_REGION_SIZE-1)) begin
                        finalize_writing_next_cycle <= 1'b1;
                    end
                end
                COMPUTING: begin
                    
                    // Pipes to know when reading n and m blocks and when it has stop
                    n_m_reading_valid_pipe1 <= n_m_reading_valid;
                    n_m_reading_valid_pipe2 <= n_m_reading_valid_pipe1; // (Correct delay when first data block received is valid)
                    n_m_reading_valid_pipe3 <= n_m_reading_valid_pipe2; // (Correct delay when first data block received is valid)
                    if (!n_m_reading_valid & !n_m_reading_valid_pipe1 & !n_m_reading_valid_pipe2 & !n_m_reading_valid_pipe3) begin // add extra pipe? Should only be 2 cycles
                        state <= OUTPUTING;
                        computing_done <= 1'b1;
                    end

                    // Pipes to know accumulator write address corresponding to accumulator write block
                    accumulator_addr_pipe1 <= accumulator_bram_B_read_addr;
                    accumulator_addr_pipe2 <= accumulator_addr_pipe1;
                    accumulator_addr_pipe3 <= accumulator_addr_pipe2;
                    accumulator_bram_A_write_addr <= accumulator_addr_pipe3; 

                    // ADDRESS LOGIC
                    if (n_m_bram_A_addr == BRAM_REGION_SIZE) begin
                        // Notice the extra cycle here!!! (This will be associated to a 0 block, to add remaining stuff to the accumulator)
                        n_m_bram_A_addr <= 0;
                        if (n_m_bram_B_addr == 2*BRAM_REGION_SIZE-1) begin
                            n_m_reading_valid <= 1'b0;
                        end 
                        else begin
                            n_m_bram_B_addr <= n_m_bram_B_addr + 1'b1;
                            accumulator_bram_B_read_addr <= accumulator_bram_B_read_addr - (BRAM_REGION_SIZE-1); // reset A to 0 (-128), increase B by 1 (+1)
                        end
                    end
                    else begin
                        n_m_bram_A_addr <= n_m_bram_A_addr + 1'b1; 
                        accumulator_bram_B_read_addr <= accumulator_bram_B_read_addr + 1'b1; // A increased by 1, fixed B
                    end

                    // COMPUTING LOGIC (also see always_comb)
                    if (n_m_reading_valid_pipe2) begin

                        // product <= n_m_bram_A_read_data_block * n_m_bram_B_read_data_block; 
                        
                        // Babbage products (with four products instead of Karatsuba's 3)
                        bab_z0 <= n_m_bram_A_read_data_block[REGISTER_SIZE/2-1:0] * n_m_bram_B_read_data_block[REGISTER_SIZE/2-1:0]; 
                        bab_z1_a <= n_m_bram_A_read_data_block[REGISTER_SIZE-1:REGISTER_SIZE/2] * n_m_bram_B_read_data_block[REGISTER_SIZE/2-1:0];
                        bab_z1_b <= n_m_bram_A_read_data_block[REGISTER_SIZE/2-1:0] * n_m_bram_B_read_data_block[REGISTER_SIZE-1:REGISTER_SIZE/2];
                        bab_z2 <= n_m_bram_A_read_data_block[REGISTER_SIZE-1:REGISTER_SIZE/2] * n_m_bram_B_read_data_block[REGISTER_SIZE-1:REGISTER_SIZE/2];

                        
                        valid_product <= 1; // give an additional cycle to write the first product into the register
                        if (valid_product) begin
                            // store results of product for the next sum
                            prev_upper_prod <= upper_prod; // (its initialized to 0 at the beginning)
                            prev_prod_sum_carry <= prod_sum[REGISTER_SIZE]; // (also initialized to 0)
                            prev_accumulator_sum_carry <= accumulator_sum_carry;
                        end
                    end
                    if (n_m_reading_valid_pipe3)
                        accumulator_bram_A_write_data_block <= accumulator_sum_block;


                end
                default: begin // OUTPUTTING

                    computing_done_pipe1 <= computing_done; 
                    computing_done_pipe2 <= computing_done_pipe1;
                    computing_done_pipe3 <= computing_done_pipe2;
                    computing_done_pipe4 <= computing_done_pipe3;
                    if (computing_done)
                        // accumulator_bram_B_read_addr <= 0;
                        block_loaded <= 1'b1;

                    if (final_out) begin
                        state <= IDLE;
                        final_out <= 1'b0;

                    end else if (accumulator_bram_B_read_addr == BRAM_DEPTH-1) begin
                        final_pipe1 <= 1'b1;
                        final_pipe2 <= final_pipe1;
                        final_out <= final_pipe2;
                        accumulator_bram_B_read_addr <= accumulator_bram_B_read_addr;
                        block_loaded <= !block_loaded;
                    end else begin
                        if (computing_done_pipe2)
                        block_loaded <= !block_loaded;

                        if (computing_done_pipe2) begin
                        accumulator_bram_B_read_addr <= (block_loaded) ? accumulator_bram_B_read_addr + 1'b1 : accumulator_bram_B_read_addr;

                        // clean the block
                        accumulator_bram_A_write_addr <= (block_loaded) ? accumulator_bram_A_write_addr + 1'b1 : accumulator_bram_A_write_addr;
                        accumulator_bram_A_write_data_block <= 0;
                        end
                    end

                end

            endcase

        end

    end


    // COMPUTING COMBINATIONAL LOGIC AND WIRES/REGS DECLARATIONS
    logic valid_product;
    logic [2*REGISTER_SIZE-1:0] product;
    logic [REGISTER_SIZE-1:0] lower_prod;
    logic [REGISTER_SIZE-1:0] upper_prod;

    logic [REGISTER_SIZE-1:0] bab_z0;
    logic [REGISTER_SIZE-1:0] bab_z1_a;
    logic [REGISTER_SIZE-1:0] bab_z1_b;
    logic [REGISTER_SIZE-1:0] bab_z2;

    logic [REGISTER_SIZE-1:0] prev_upper_prod;
    logic prev_prod_sum_carry;

    logic [REGISTER_SIZE:0] prod_sum;

    logic [REGISTER_SIZE:0] accumulator_sum;
    logic [REGISTER_SIZE-1:0] accumulator_sum_block;
    logic accumulator_sum_carry;
    logic prev_accumulator_sum_carry;

    logic final_pipe1;
    logic final_pipe2;
    always_comb begin

        // (above we have: product <= n_m_bram_A_read_data_block * n_m_bram_B_read_data_block )
        product = (bab_z2 << REGISTER_SIZE) + ((bab_z1_a + bab_z1_b) << REGISTER_SIZE/2) + bab_z0;
        lower_prod = product[REGISTER_SIZE-1:0];
        upper_prod = product[2*REGISTER_SIZE-1:REGISTER_SIZE];

        // add corresponding product blocks pairs
        prod_sum = lower_prod + prev_upper_prod + prev_prod_sum_carry;

        // get updated accumulator block
        accumulator_sum = accumulator_bram_B_read_data_block_piped + prod_sum[REGISTER_SIZE-1:0] + prev_accumulator_sum_carry;
        accumulator_sum_block = accumulator_sum[REGISTER_SIZE-1:0];
        accumulator_sum_carry = accumulator_sum[REGISTER_SIZE];

        // Out data block
        data_out = (block_loaded) 
                        ? accumulator_bram_B_read_data_block[REGISTER_SIZE-1:REGISTER_SIZE_IN]
                        : accumulator_bram_B_read_data_block[REGISTER_SIZE_IN-1:0];
        valid_out = (state == OUTPUTING && computing_done_pipe3);
        
        ready_out = (state == IDLE);

    end


endmodule
`default_nettype wire