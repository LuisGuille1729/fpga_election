module cocotb_iverilog_dump();
initial begin
    $dumpfile("/home/yoshicabeza/6.205/final_project/fpga_election/fpga_e/sim/sim_build/fsm_multiplier.fst");
    $dumpvars(0, fsm_multiplier);
end
endmodule
