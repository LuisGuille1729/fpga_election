

import cocotb
from cocotb.triggers import Timer
import os
from pathlib import Path
import sys

from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,ReadWrite,with_timeout, First, Join
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner


import random

from random import getrandbits

async def reset(rst,clk):
    """ Helper function to issue a reset signal to our module """
    rst.value = 1
    await ClockCycles(clk,3)
    rst.value = 0
   
    
@cocotb.test()
async def  find_test(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    test_set = set()
    await reset(dut.rst_in,dut.clk_in)
    for i in range(100000):
        await ClockCycles(dut.clk_in,1)
        test_set.add(int(dut.rand_out.value))
    print(len(test_set))
REGISTER_SIZE = 32
BITS_IN_NUM = 4096
def test_tmds_runner():
    """Run the TMDS runner. Boilerplate code"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "LFSR32.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="LFSR32",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ns'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="LFSR32",
        test_module="test_LFSR32",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_tmds_runner()