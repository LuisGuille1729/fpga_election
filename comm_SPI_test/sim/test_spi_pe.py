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
    dut.data_in.value = 12
    
    dut.chip_data_in.value = 0
    dut.chip_clk_in.value = 0
    dut.chip_sel_in.value = 0
    
    await ClockCycles(dut.clk_in, 20)
    
    dut.rst_in.value = 0
    
    dut.chip_sel_in.value = 1
    dut.chip_data_in.value = 1
    dut.chip_clk_in.value = 0
    
    
    dut.valid_in.value = 0
    dut.data_in.value = 14
    
    await ClockCycles(dut.clk_in, 20)
    
    
    for val in [1, 1, 0, 1, 0, 0, 1, 1]:
        dut.chip_sel_in.value = 0
        dut.chip_data_in.value = val
        dut.chip_clk_in.value = 1
        
        await ClockCycles(dut.clk_in, 5)

        dut.chip_clk_in.value = 0
        await ClockCycles(dut.clk_in, 5)
        dut.chip_clk_in.value = 1
    
    dut.chip_sel_in.value = 1
    
    await ClockCycles(dut.clk_in, 10)
    
    for val in [0, 1, 0, 1, 0, 0, 1, 1]:
        dut.chip_sel_in.value = 0
        dut.chip_data_in.value = val
        dut.chip_clk_in.value = 1
        
        await ClockCycles(dut.clk_in, 5)

        dut.chip_clk_in.value = 0
        await ClockCycles(dut.clk_in, 5)
        dut.chip_clk_in.value = 1 
        
    dut.chip_sel_in.value = 1
    
    await ClockCycles(dut.clk_in, 10)
    
 
"""the code below should largely remain unchanged in structure, though the specific files and things
specified should get updated for different simulations.
"""
def spi_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "spi_pe.sv"] #grow/modify this as needed.
    build_test_args = ["-Wall"]#,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="spi_pe",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="spi_pe",
        test_module="test_spi_pe",
        test_args=run_test_args,
        waves=True
    )
 
if __name__ == "__main__":
    spi_runner()