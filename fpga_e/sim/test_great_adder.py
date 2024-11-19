

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



async def send_num(dut,clk_in,num1,num2):
    dut.a_in.value = num1
    dut.b_in.value = num2
    dut.valid_in.value = 1
    await ClockCycles(clk_in,1)
    dut.valid_in.value = 0



async def test_nums(dut,num_1,num_2):
    running_sum = 0;
    blocks_added = 0
    dut.carry_in.value = 0
    expected_sum = num_1+num_2
    for i in range(bits_in_num//register_size):
        a_i = num_1//(2**(register_size*i))% (2**register_size)
        b_i = num_2//(2**(register_size*i))% (2**register_size)
        await send_num(dut,dut.clk_in,a_i,b_i)
        if (dut.valid_out.value == 1):
            running_sum += (int(dut.data_out.value))*(2**(register_size*blocks_added))
            blocks_added += 1
        if (dut.final_out.value != 1):
            await ClockCycles(dut.clk_in,4)
    while (dut.final_out.value == 0):
        await ClockCycles(dut.clk_in,1)
        if (dut.valid_out.value == 1):
            running_sum += (int(dut.data_out.value))*(2**(register_size*blocks_added))
            blocks_added += 1
    running_sum += dut.carry_out.value*2**(register_size*blocks_added)
    # print("actual sum", running_sum)
    assert(running_sum == expected_sum)
@cocotb.test()
async def  test_kernel(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.valid_in.value = 0
    await reset(dut.rst_in,dut.clk_in)

    num_2 = 3677

    for num_1 in range(2**bits_in_num):
        await test_nums(dut,num_1,num_2)



    
    
    


register_size = 2
bits_in_num = 12
def test_tmds_runner():
    """Run the TMDS runner. Boilerplate code"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "great_adder.sv", proj_path / "hdl" / "pipeliner.sv", proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v"]
    build_test_args = ["-Wall"]
    parameters = {"register_size": register_size, "bits_in_num": bits_in_num}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="great_adder",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ns'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="great_adder",
        test_module="test_great_adder",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_tmds_runner()