

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
    dut.low_in.value = num1
    dut.high_in.value = num2
    dut.valid_in.value = 1
    await ClockCycles(clk_in,1)
    dut.valid_in.value = 0




async def test_nums(dut,num_1,num_2):
    running_store = 0;
    nums_received = 0
    num_1 = num_1%(num_bits_stored)
    num_2 = num_2%(num_bits_stored)
    expected_out = num_1 + 2**(desired_size + register_size)*num_2
    desired_num_outputs = 2*desired_size//register_size
    for i in range(num_bits_stored//register_size):
        n_i = num_1//(2**(register_size*i))% (2**register_size)
        m_i = num_2//(2**(register_size*i))% (2**register_size)
        await send_num(dut,dut.clk_in,n_i,m_i)
        if (dut.valid_out.value == 1):
            running_store += (int(dut.data_out.value))*(2**(register_size*nums_received))
            nums_received += 1
    while (nums_received < (desired_num_outputs)):
        await ClockCycles(dut.clk_in,1)
        if (dut.valid_out.value == 1):
            running_store += (int(dut.data_out.value))*(2**(register_size*nums_received))
            nums_received += 1
    assert(expected_out == running_store)


async def test_dream_nums(dut,num_1,num_2,offset):
    running_store = 0;
    nums_received = 0
    dut.start_padding.value = offset
    num_1 = num_1%(num_bits_stored)
    num_2 = num_2%(num_bits_stored)
    expected_out = 2**(offset*register_size)*(num_1 + 2**(desired_size + register_size)*num_2)
    desired_num_outputs = 2*desired_size//register_size
    for i in range(num_bits_stored//register_size):
        n_i = num_1//(2**(register_size*i))% (2**register_size)
        m_i = num_2//(2**(register_size*i))% (2**register_size)
        await send_num(dut,dut.clk_in,n_i,m_i)
        if (dut.valid_out.value == 1):
            running_store += (int(dut.data_out.value))*(2**(register_size*nums_received))
            nums_received += 1
    while (nums_received != (desired_num_outputs)):
        await ClockCycles(dut.clk_in,1)
        if (dut.valid_out.value == 1):
            running_store += (int(dut.data_out.value))*(2**(register_size*nums_received))
            nums_received += 1
    # print("expected", expected_out)
    print("got", running_store)
    assert(expected_out == running_store)


    
@cocotb.test()
async def  test_kernel(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.valid_in.value = 0
    await reset(dut.rst_in,dut.clk_in)

    while (dut.ready_out.value != 1):
        await ClockCycles(dut.clk_in,1)

    # num_2 = 3677
    # dut.start_padding.value = 0
    # await test_nums(dut,3,3);
    # await test_nums(dut,3,0);
    # await test_nums(dut,0,3);
    # for num in range(100):
    #     await test_nums(dut,num,num*num);    
    #     await test_nums(dut,num*num,num);  


@cocotb.test()
async def  dream_test(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.valid_in.value = 0
    await reset(dut.rst_in,dut.clk_in)

    while (dut.ready_out.value != 1):
        await ClockCycles(dut.clk_in,1)

    # num_2 = 3677
    dut.start_padding.value = 0
    # await test_dream_nums(dut,1,0,0);
    # await test_dream_nums(dut,3,0,1);
    # await test_dream_nums(dut,0,3,2);
    # for num in range(100):
    #     await test_dream_nums(dut,num,num*num,0);    
    #     await test_dream_nums(dut,num*num,num,1);  
    #     await test_dream_nums(dut,num,num*num,2);  
    #     await test_dream_nums(dut,num,num*num,3);
    #     await test_dream_nums(dut,num,num*num,4);    
    #     await test_dream_nums(dut,num*num,num,5);  
    #     await test_dream_nums(dut,num,num*num,6);  
    #     await test_dream_nums(dut,num,num*num,7);   
    
    
@cocotb.test()
async def  find_test(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.valid_in.value = 0
    await reset(dut.rst_in,dut.clk_in)

    while (dut.ready_out.value != 1):
        await ClockCycles(dut.clk_in,1)

    # num_2 = 3677
    dut.start_padding.value = 0
    await test_dream_nums(dut,0,1,2);  
    

register_size = 2
num_bits_stored = 6
desired_size = 32;
def test_tmds_runner():
    """Run the TMDS runner. Boilerplate code"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "mul_store.sv", proj_path / "hdl" / "pipeliner.sv", proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v"]
    build_test_args = ["-Wall"]
    parameters = {"register_size": register_size, "num_bits_stored": num_bits_stored, "desired_size": desired_size}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="mul_store",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ns'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="mul_store",
        test_module="test_mul_store",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_tmds_runner()