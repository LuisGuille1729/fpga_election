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
    dut.rst_in.value = 0
    dut.data_out.value = 0x1a
    dut.chip_data_out = 0b1
    dut.chip_clk_out = 0b1
    await ClockCycles(dut.clk_in, 100) # (100*10ns = 1000ns)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 140)
    assert dut.data_out.value == 0, "data_out should hold 0 after rst_in."
    assert dut.data_valid_out.value == 0, "data_valid_out not holding 0 after rst_in."
    assert dut.chip_data_out.value == 0, "chip_data_out not holding 0 after rst_in."
    assert dut.chip_clk_out.value == 0, "chip_clk_out not holding 0 after rst_in."
    assert dut.chip_sel_out.value == 1, "chip_sel_out not holding 0 after rst_in."
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in, 30)

    dut.chip_data_in.value = 0b1

    # Test trigger, values, and clock
    dut.data_in.value = 0b10110010
    dut.trigger_in.value = 0b1
    await ClockCycles(dut.clk_in, 53)   # 1 from 53, 53, .., 103 (51 cycles) changes after 51 cycles instead of 50 (fine?)
    assert dut.chip_clk_out.value == 1, "chip_clk_out now 1 after over 50 cycles after trigger."
    dut.data_in.value = 0b0
    await ClockCycles(dut.clk_in, 51)  # 0 from 51, 52, ..., 
    assert dut.chip_clk_out.value == 0, "chip_clk_out now 0 after exactly 50 cycles after up."
    dut.trigger_in.value = 0b0
    assert dut.send_data.value == 0b10110010, "send_data should not change after changing data_in"
    await ClockCycles(dut.clk_in, 51)
    assert dut.chip_clk_out.value == 1, "chip_clk_out now 1 after exactly 50 cycles after up."
    await ClockCycles(dut.clk_in, 800)
    
    # Send new message
    dut.data_in.value = 0b1010111
    dut.trigger_in.value = 0b1    

    assert dut.chip_clk_out.value == 0, "down 1"
    dut.chip_data_in.value = 0b1
    await ClockCycles(dut.clk_in, 53)
    
    assert dut.chip_clk_out.value == 1, "up 1"
    await ClockCycles(dut.clk_in, 51)

    assert dut.chip_clk_out.value == 0, "down 2"
    dut.chip_data_in.value = 0b0
    dut.trigger_in.value = 0b0
    await ClockCycles(dut.clk_in, 51)
    
    assert dut.chip_clk_out.value == 1, "up 2"
    await ClockCycles(dut.clk_in, 51)
    
    assert dut.chip_clk_out.value == 0, "down 3"
    dut.chip_data_in.value = 0b1
    await ClockCycles(dut.clk_in, 51)
    
    assert dut.chip_clk_out.value == 1, "up 3"
    await ClockCycles(dut.clk_in, 51)
    
    assert dut.chip_clk_out.value == 0, "down 4"
    dut.chip_data_in.value = 0b1
    await ClockCycles(dut.clk_in, 51)
    
    assert dut.chip_clk_out.value == 1, "up 4"
    await ClockCycles(dut.clk_in, 51)
    
    assert dut.chip_clk_out.value == 0, "down 5"
    dut.chip_data_in.value = 0b0
    await ClockCycles(dut.clk_in, 51)
    
    assert dut.chip_clk_out.value == 1, "up 5"
    await ClockCycles(dut.clk_in, 51)
    
    assert dut.chip_clk_out.value == 0, "down 6"
    dut.chip_data_in.value = 0b1
    await ClockCycles(dut.clk_in, 51)
    
    assert dut.chip_clk_out.value == 1, "up 6"
    await ClockCycles(dut.clk_in, 51)
    
    assert dut.chip_clk_out.value == 0, "down 7"
    dut.chip_data_in.value = 0b0
    await ClockCycles(dut.clk_in, 51)
    
    assert dut.chip_clk_out.value == 1, "up 7"
    await ClockCycles(dut.clk_in, 51)
 
    await ClockCycles(dut.clk_in, 200)
 
"""the code below should largely remain unchanged in structure, though the specific files and things
specified should get updated for different simulations.
"""
def spi_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "spi_con.sv"] #grow/modify this as needed.
    build_test_args = ["-Wall"]#,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="spi_con",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="spi_con",
        test_module="test_spi",
        test_args=run_test_args,
        waves=True
    )
 
if __name__ == "__main__":
    spi_runner()