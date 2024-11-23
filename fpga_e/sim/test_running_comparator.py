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
 
async def send(dut, blockA_value, blockB_value):
    dut.valid_in.value = 1 
    dut.block_numA_in.value = blockA_value
    dut.block_numB_in.value = blockB_value
    await ClockCycles(dut.clk_in, 1)
    
    
async def delay(dut, time, addRandomDelay=False):
    dut.valid_in.value = 0
    await ClockCycles(dut.clk_in, time)
    if addRandomDelay:
        await ClockCycles(dut.clk_in, random.randint(0, 1))
 
async def comparison_test(dut, A, B):
    print(f"Compare: A is {A.bit_length()}-bits, B is {B.bit_length()}-bits.")
    if (A == B):
        expected = 0b11
    elif (A < B):
        expected = 0b01
    else:
        expected = 0b10
    
    
    for count in range(128):
        A_in = A & (0xFFFF_FFFF)
        B_in = B & (0xFFFF_FFFF)
        await send(dut, A_in, B_in)
        A = A >> 32
        B = B >> 32
        
        if count != 127:
            assert dut.end_comparison_out.value == 0
        assert dut.block_count.value == count    
    
    assert dut.end_comparison_out.value == 1
    assert int(dut.comparison_result_out.value) == expected
 
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
    
    #### Test EQUALITY ####
    A = random.randint(2**4095, 2**4096-1)
    # B = A
    print(f"A = B. A is {A.bit_length()}-bits, B is {A.bit_length()}-bits.")
    
    count = 0
    while A != 0:
        A_in = A & (0xFFFF_FFFF)
        await send(dut, A_in, A_in)
        A = A >> 32
        # B = B >> 32
        
        assert dut.comparison_result_out.value == 0b11
        
        print(count)
        assert dut.block_count.value == count    
        count += 1
    
    assert dut.end_comparison_out.value == 1
    await delay(dut, 1, addRandomDelay=False)
    assert dut.comparison_result_out.value == 0
    assert dut.end_comparison_out.value == 0
    await delay(dut, 10, addRandomDelay=False) 
    
    #### Test A LESS THAN B ####
    B = random.randint(2**4095, 2**4096-1)
    A = B - random.randint(0, 2**4094)
    print(f"A < B. A is {A.bit_length()}-bits, B is {B.bit_length()}-bits.")
    
    count = 0
    while A != 0:
        A_in = A & (0xFFFF_FFFF)
        B_in = B & (0xFFFF_FFFF)
        await send(dut, A_in, B_in)
        A = A >> 32
        B = B >> 32
        
        
        print(count)
        assert dut.block_count.value == count    
        count += 1
    
    assert dut.end_comparison_out.value == 1
    assert dut.comparison_result_out.value == 0b01
    await delay(dut, 1, addRandomDelay=False)
    assert dut.comparison_result_out.value == 0
    await delay(dut, 10, addRandomDelay=False) 
    
    #### Test A GREATER THAN B ####
    A = random.randint(2**4095, 2**4096-1)
    B = A - random.randint(0, 2**4094)
    print(f"A > B. A is {A.bit_length()}-bits, B is {B.bit_length()}-bits.")
    
    count = 0
    while A != 0:
        A_in = A & (0xFFFF_FFFF)
        B_in = B & (0xFFFF_FFFF)
        await send(dut, A_in, B_in)
        A = A >> 32
        B = B >> 32
        
        
        print(count)
        assert dut.block_count.value == count    
        count += 1
    
    assert dut.end_comparison_out.value == 1
    assert dut.comparison_result_out.value == 0b10
    await delay(dut, 1, addRandomDelay=False)
    assert dut.comparison_result_out.value == 0
    await delay(dut, 10, addRandomDelay=False) 
    
    
    ### STRESS TEST ###
    print("Stress test:")
    for _ in range(100):
        A = random.randint(0, 2**4096-1)
        B = random.randint(0, 2**4096-1)
        await comparison_test(dut, A, B)
    
    for _ in range(100):
        # test with very small differences
        A = random.randint(0, 2**4096-1)
        B = A + random.choice([0, 2**100, -(2**100), 1, -1])
        await comparison_test(dut, A, B)
    
 
"""the code below should largely remain unchanged in structure, though the specific files and things
specified should get updated for different simulations.
"""
def test_runner():
    """Simulate using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "running_comparator.sv"] #grow/modify this as needed.
    build_test_args = ["-Wall"]#,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="running_comparator",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="running_comparator",
        test_module="test_running_comparator",
        test_args=run_test_args,
        waves=True
    )
 
if __name__ == "__main__":
    test_runner()