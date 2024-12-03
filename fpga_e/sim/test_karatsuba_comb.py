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
   
async def test(dut, x, y):
    dut.x_in.value = x
    dut.y_in.value = y
    await ClockCycles(dut.clk_in, 1)
    assert dut.data_out.value == x*y, f"Error multiplying {x} * {y}"
    
@cocotb.test()
async def  first_test(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.x_in.value = 0
    dut.y_in.value = 0
    await ClockCycles(dut.clk_in, 5)
    assert dut.data_out.value == 0*0, f"Error multiplying 0 * 0"
    
    dut.x_in.value = 0xFFFF_FFF0
    dut.y_in.value = 0x0000_000A
    await ClockCycles(dut.clk_in, 5)
    assert dut.data_out.value == 0xFFFF_FFF0*0x0000_000A, f"Error multiplying"
    
    # await test(dut, 2, 2)
    
    await test(dut, 3825050834, 4086943809)
    
    for _ in range(100000):
        x = random.randint(0, 2**REGISTER_SIZE-1)
        y = random.randint(0, 2**REGISTER_SIZE-1)
        await test(dut, x, y)
    
    
    
    
    



REGISTER_SIZE = 64
def test_runner():
    """Run the TMDS runner. Boilerplate code"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "karatsuba_comb.sv"]
    build_test_args = ["-Wall"]
    parameters = {"REGISTER_SIZE": REGISTER_SIZE}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="karatsuba_comb",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ns'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="karatsuba_comb",
        test_module="test_karatsuba_comb",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_runner()