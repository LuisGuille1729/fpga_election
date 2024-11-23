import cocotb
import os
import random
import sys
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly
from cocotb.triggers import Timer
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
 
async def send(dut, block_value):
    dut.valid_in.value = 1 
    dut.block_in.value = block_value
    # print(dut.valid_out.value)
    await ClockCycles(dut.clk_in, 1)
    
    
async def delay(dut, time, addRandomDelay=True):
    dut.valid_in.value = 0
    await ClockCycles(dut.clk_in, time)
    if addRandomDelay:
        await ClockCycles(dut.clk_in, random.randint(0, 1))
 
@cocotb.test()
async def first_test(dut):
    """ First cocotb test?"""
    # write your test here!
	  # throughout your test, use "assert" statements to test for correct behavior
	  # replace the assertion below with useful statements
    # default parameters are DATA_WIDTH = 8, DATA_CLK_PERIOD = 100
    dut._log.info("Starting...")
    # Start clock with 10ns period (100MHz frequency)
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start()) 

    # Test rst_in
    dut.rst_in.value = 1
    dut.valid_in.value = 0
    await ClockCycles(dut.clk_in, 10)
    
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in, 20)

    for i in range(1, 257):
        await send(dut, i + (i**2)*2**8)
        
        if i <= 128:
            assert dut.valid_out.value == 0
            
        if i > 128:
            assert dut.valid_out.value == 1
            assert dut.data_block_out.value == i + (i**2)*2**8
            
        await delay(dut, 1)

    await delay(dut, 1)
    assert dut.valid_out.value == 0 

    # Send again!
    for i in range(1, 257):
        await send(dut, i + (i**2)*2**8)
        
        if i <= 128:
            assert dut.valid_out.value == 0
            
        if i > 128:
            assert dut.valid_out.value == 1
            assert dut.data_block_out.value == i + (i**2)*2**8
            
        await delay(dut, 1)

    await delay(dut, 1)
    assert dut.valid_out.value == 0 
    
    
    
 
"""the code below should largely remain unchanged in structure, though the specific files and things
specified should get updated for different simulations.
"""
def test_runner():
    """Simulate using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "right_shifter.sv"] #grow/modify this as needed.
    build_test_args = ["-Wall"]#,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="right_shifter",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="right_shifter",
        test_module="test_right_shifter",
        test_args=run_test_args,
        waves=True
    )
 
if __name__ == "__main__":
    test_runner()