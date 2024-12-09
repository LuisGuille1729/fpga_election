

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



async def send_num(dut,num1):
    dut.data_in.value = num1
    dut.valid_in.value = 1
    await ClockCycles(dut.clk_in,1)
    dut.valid_in.value = 0


async def uart_wait(dut):
    uart_delay = 8
    dut.request_next_byte_in = 0
    await ClockCycles(dut.clk_in,uart_delay)
    dut.request_next_byte_in = 1
    await ClockCycles(dut.clk_in,1)
    
async def nondet_test(dut):

    rand_num = random.randint(0,2**BITS_IN_NUM-1)
    dut.request_next_byte_in = 1
    expected_res = rand_num
    for i in range(NUM_BLOCKS):
        sel = rand_num & (2**REGISTER_SIZE -1)
        await send_num(dut,sel)
        rand_num = rand_num >> REGISTER_SIZE
        assert(dut.valid_out.value != 1)
    accum =0
    byte_size = 8
    rec_block_size = REGISTER_SIZE//byte_size
    num_receive_blocks = NUM_BLOCKS* (rec_block_size);
    i = 0
    await ClockCycles(dut.clk_in,1)
    while i != num_receive_blocks:
        if (dut.valid_out.value == 1):
            accum += (int(dut.data_out.value))*(2**(byte_size*i))
            i += 1
            await uart_wait(dut)
    assert(dut.valid_out.value != 1)
    # print(accum)
    # print(expected_res)
    assert(accum == expected_res)





@cocotb.test()
async def  find_test(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await reset(dut.rst_in,dut.clk_in)
    await nondet_test(dut)

REGISTER_SIZE = 32
BITS_IN_NUM = 4096
NUM_BLOCKS = BITS_IN_NUM//REGISTER_SIZE
def test_tmds_runner():
    """Run the TMDS runner. Boilerplate code"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "fsm_multiplier.sv", proj_path / "hdl" / "pipeliner.sv", proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v",
               proj_path / "hdl" / "bram_blocks_rw.sv", proj_path / "hdl" / "byte_repeater.sv",
               proj_path / "hdl" / "evt_counter.sv",
               
               ]
    build_test_args = ["-Wall"]
    parameters = {"REGISTER_SIZE": REGISTER_SIZE, "BITS_IN_NUM": BITS_IN_NUM}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="byte_repeater",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ns'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="byte_repeater",
        test_module="test_byte_repeater",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_tmds_runner()