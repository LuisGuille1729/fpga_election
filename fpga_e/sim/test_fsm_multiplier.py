

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
    dut.n_in.value = num1
    dut.m_in.value = num2
    dut.valid_in.value = 1
    await ClockCycles(clk_in,1)
    dut.valid_in.value = 0




async def test_nums(dut,num_1,num_2):
    running_prod = 0;
    nums_received = 0
    num_1 = num_1%(2**bits_in_num)
    num_2 = num_2%(2**bits_in_num)
    expected_product = num_1*num_2
    # max_wait = 10000
    print("expected prod", expected_product)
    for i in range(bits_in_num//register_size):
        n_i = num_1//(2**(register_size*i))% (2**register_size)
        m_i = num_2//(2**(register_size*i))% (2**register_size)
        await send_num(dut,dut.clk_in,n_i,m_i)
        if (dut.valid_out.value == 1):
            # print("got", int(dut.data_out.value))
            running_prod += (int(dut.data_out.value))*(2**(register_size*nums_received))
            nums_received += 1
        
    while (nums_received < 2*bits_in_num//register_size ):
        await ClockCycles(dut.clk_in,1)
        # print("got", int(dut.data_out.value))
        if (dut.valid_out.value == 1):
            running_prod += (int(dut.data_out.value))*(2**(register_size*nums_received))
            nums_received += 1
        # max_wait -= 1
    print(num_1,num_2)
    print("actual prod", running_prod)
    while (dut.ready_out.value != 1):
            await ClockCycles(dut.clk_in,1)
    await ClockCycles(dut.clk_in,10)
    assert(running_prod == expected_product)


    
@cocotb.test()
async def  test_kernel(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.valid_in.value = 0
    await reset(dut.rst_in,dut.clk_in)

    # num_2 = 3677
    # await test_nums(dut,1023,1);
    # await test_nums(dut,2048,512);
    # await test_nums(dut,1,2048);
    # for i in range(2**12):
    #     await test_nums(dut,i,2047);
    # for i in range(2**12):
        # await test_nums(dut,i,i);
    # for num_1 in range(2**bits_in_num):
    #     await test_nums(dut,num_1,num_2)    
    
@cocotb.test()
async def  find_test(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.valid_in.value = 0
    await reset(dut.rst_in,dut.clk_in)

    # num_2 = 3677
    # await test_nums(dut,2,2**(bits_in_num-2));
    # await test_nums(dut,2,2**(bits_in_num-1));
    # await test_nums(dut,1,2048);
    # for i in range(2**12):
    #     await test_nums(dut,i,2047);
    for i in range(2**bits_in_num):
        await test_nums(dut,i,i);
    # for num_1 in range(2**bits_in_num):
    #     await test_nums(dut,num_1,num_2)    

register_size = 2
bits_in_num = 12
def test_tmds_runner():
    """Run the TMDS runner. Boilerplate code"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "fsm_multiplier.sv", proj_path / "hdl" / "pipeliner.sv", proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v",
               proj_path / "hdl" / "mul_store.sv", proj_path / "hdl" / "accumulator.sv",]
    build_test_args = ["-Wall"]
    parameters = {"register_size": register_size, "bits_in_num": bits_in_num}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="fsm_multiplier",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ns'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="fsm_multiplier",
        test_module="test_fsm_multiplier",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_tmds_runner()