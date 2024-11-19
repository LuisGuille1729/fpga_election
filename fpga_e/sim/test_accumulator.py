

import cocotb
from cocotb.triggers import Timer
import os
from pathlib import Path
import sys

from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,ReadWrite,with_timeout, First, Join
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

from random import getrandbits

async def reset(rst,clk):
    """ Helper function to issue a reset signal to our module """
    rst.value = 1
    await ClockCycles(clk,3)
    rst.value = 0



async def send_num(dut,clk_in,num1):
    dut.block_in.value = num1
    dut.valid_in.value = 1
    await ClockCycles(clk_in,1)
    dut.valid_in.value = 0




async def test_nums(dut,num_1,cur_sum):
    accum_sum = 0;
    nums_received = 0
    expected_sum = (num_1 +cur_sum)%(2**num_bits_stored)
    max_wait = 10000
    for i in range(num_bits_stored//register_size):
        a_i = num_1//(2**(register_size*i))% (2**register_size)
        await send_num(dut,dut.clk_in,a_i)
        if (dut.valid_out.value == 1):
            accum_sum += (int(dut.data_out.value))*(2**(register_size*nums_received))
            nums_received += 1
    while (nums_received < num_bits_stored//register_size):
        await ClockCycles(dut.clk_in,1)
        if (dut.valid_out.value == 1):
            accum_sum += (int(dut.data_out.value))*(2**(register_size*nums_received))
            nums_received += 1
        max_wait -= 1
    # print(accum_sum, expected_sum, cur_sum,num_1)
    assert(accum_sum == expected_sum)
    return accum_sum    


    
@cocotb.test()
async def  test_kernel(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.valid_in.value = 0
    await reset(dut.rst_in,dut.clk_in)

    while (dut.ready_out.value != 1):
        await ClockCycles(dut.clk_in,1)

    # num_2 = 3677
    cur_sum = 0
    for i in range(2**num_bits_stored):
        cur_sum = await test_nums(dut,i,cur_sum);
    await reset(dut.rst_in,dut.clk_in)
    while (dut.ready_out.value != 1):
        await ClockCycles(dut.clk_in,1)
    cur_sum = 0
    for i in range(2**num_bits_stored):
        cur_sum = await test_nums(dut,i,cur_sum);
    


register_size = 2
num_bits_stored = 12
def test_tmds_runner():
    """Run the TMDS runner. Boilerplate code"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "accumulator.sv", proj_path / "hdl" / "pipeliner.sv", proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v"]
    build_test_args = ["-Wall"]
    parameters = {"register_size": register_size, "num_bits_stored": num_bits_stored}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="accumulator",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ns'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="accumulator",
        test_module="test_accumulator",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_tmds_runner()