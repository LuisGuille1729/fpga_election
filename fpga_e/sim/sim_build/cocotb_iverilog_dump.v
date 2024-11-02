module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/turino14/6205/secure_election/fpga_e/sim/sim_build/comb_adder.fst");
    $dumpvars(0, comb_adder);
end
endmodule
