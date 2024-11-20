module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/turino14/6205/secure_election/fpga_e/sim/sim_build/modulo_of_power.fst");
    $dumpvars(0, modulo_of_power);
end
endmodule
