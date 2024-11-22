module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/turino14/6205/secure_election/fpga_e/sim/sim_build/right_shifter.fst");
    $dumpvars(0, right_shifter);
end
endmodule
