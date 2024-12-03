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

def dispatch_blocks(value, num_blocks, infinite=True):
    while True:
        val = value
        for _ in range(num_blocks):
            yield val & (2**REGISTER_SIZE-1)
            val = val >> REGISTER_SIZE
        # print(f"Looping after {num_blocks}")
        
        if infinite is False:
            break

async def reset(rst,clk):
    """ Helper function to issue a reset signal to our module """
    rst.value = 1
    await ClockCycles(clk,10)
    rst.value = 0


async def send_num(dut,num1,num2):
    # print(num1, num2)
    dut.n_in.value = num1
    dut.m_in.value = num2
    dut.valid_in.value = 1
    await ClockCycles(dut.clk_in,1)
    dut.valid_in.value = 0

async def test_mem(dut, num_1, num_2):
    n_blocks = dispatch_blocks(num_1, BLOCKS_INPUT)
    m_blocks = dispatch_blocks(num_2, BLOCKS_INPUT)
    
    dut.valid_in.value = 0
    for _ in range(128):
        await send_num(dut, next(n_blocks), next(m_blocks))
    
    await ClockCycles(dut.clk_in, 200)

async def test_product(dut, num_1, num_2):
    n_blocks = dispatch_blocks(num_1, BLOCKS_INPUT)
    m_blocks = dispatch_blocks(num_2, BLOCKS_INPUT)
    
    cycles = 0
    dut.valid_in.value = 0
    for _ in range(128):
        await send_num(dut, next(n_blocks), next(m_blocks))
    
    cycles = 128
    
    while dut.valid_out.value == 0:
        cycles += 1
        await ClockCycles(dut.clk_in, 1)

    print(f"Done in {cycles}")
    expected = dispatch_blocks(num_1*num_2, 256, False)
    # print([hex(block) for block in expected])
    
    i = 0
    while dut.valid_out.value == 1:
        expected_val = next(expected)
        # print(expected_val)
        assert dut.data_out.value == expected_val, f"Assertion error at block {i}. Got {hex(dut.data_out.value)}, expected {hex(expected_val)}" 
        await ClockCycles(dut.clk_in, 1)    
        i += 1

async def test_nums(dut,num_1,num_2):
    running_prod = 0
    nums_received = 0
    num_1 = num_1%(2**BITS_IN_NUM)
    num_2 = num_2%(2**BITS_IN_NUM)
    expected_product = num_1*num_2
    clk_cys = 0
    for i in range(BITS_IN_NUM//REGISTER_SIZE):
        n_i = num_1//(2**(REGISTER_SIZE*i))% (2**REGISTER_SIZE)
        m_i = num_2//(2**(REGISTER_SIZE*i))% (2**REGISTER_SIZE)
        await send_num(dut,n_i,m_i)
        clk_cys += 1
        if (dut.valid_out.value == 1):
            # print("got", int(dut.data_out.value))
            running_prod += (int(dut.data_out.value))*(2**(REGISTER_SIZE*nums_received))
            nums_received += 1
    
    while (nums_received != 2*BITS_IN_NUM//REGISTER_SIZE ):
        await ClockCycles(dut.clk_in,1)
        clk_cys += 1
        # print("got", int(dut.data_out.value))
        if (dut.valid_out.value == 1):
            running_prod += (int(dut.data_out.value))*(2**(REGISTER_SIZE*nums_received))
            nums_received += 1
        # max_wait -= 1
    while (dut.ready_out.value != 1):
            await ClockCycles(dut.clk_in,1)
    # await ClockCycles(dut.clk_in,10)
    assert(running_prod == expected_product), f"{hex(running_prod)} instead of {hex(expected_product)}"
   
    
@cocotb.test()
async def  first_test(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.valid_in.value = 0
    await reset(dut.rst_in,dut.clk_in)

    num1 = 0
    num2 = 0
    for i in range(128):
        num1 += ((i+1 + 65536*4) << 32*i) 
        num2 += ((128-i + 65536*2) << 32*i)
    
    # For testing memory only (comment/uncomment COMPUTING in sv)
    # await test_mem(dut, num1, num2)

    # Test where there are no carries involved
    # await test_product(dut, num1, num2)

    # Test with some carries at start
    num1 = num1 | 0xEFFF_FFFF_FFFF_FFFF_FFFF
    num2 = num2 | 0xEFFF_FFFF_FFFF_FFFF_FFFF
    await test_product(dut, num1, num2)

    # await ClockCycles(dut.clk_in, 1)

    # Edge cases
    await test_product(dut, 2, 2**(BITS_IN_NUM-2))
    await test_nums(dut,2,2**(BITS_IN_NUM-2))

    # Test with random numbers
    num1 = random.randint(0, 2**4096-1)
    num2 = random.randint(0, 2**4096-1)
    print(f"{num1.bit_length()}-bits times {num2.bit_length()}-bits")
    await test_product(dut, num1, num2)
    
    

    # await test_nums(dut,2,2**(BITS_IN_NUM-1))
    # await test_nums(dut,1,2048)
    # for i in range(2**12):
    #     await test_nums(dut,i,2047);

    # await test_nums(dut,2**(BITS_IN_NUM-1),2**(BITS_IN_NUM-2))
    # await test_nums(dut,8,4);
    for i in range(1000):
        print("test",i)
        rand_num1 = random.randint(0, 2**BITS_IN_NUM-1)
        rand_num2 = random.randint(0, 2**BITS_IN_NUM-1)
        await test_nums(dut,rand_num1,rand_num2)
    # for num_1 in range(2**BITS_IN_NUM):
    #     await test_nums(dut,num_1,num_2)    

REGISTER_SIZE = 64
BITS_IN_NUM = 4096
BITS_IN_OUT = BITS_IN_NUM*2 # 8192
BLOCKS_INPUT = BITS_IN_NUM//REGISTER_SIZE # 128
BLOCKS_OUTPUT = BITS_IN_OUT//REGISTER_SIZE # 256
def test_runner():
    """Run the TMDS runner. Boilerplate code"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "fsm_multiplier.sv", proj_path / "hdl" / "pipeliner.sv", proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v",
               proj_path / "hdl" / "mul_store.sv", proj_path / "hdl" / "accumulator.sv", proj_path / "hdl" / "karatsuba_comb.sv"]
    build_test_args = ["-Wall"]
    parameters = {"REGISTER_SIZE": REGISTER_SIZE, "BITS_IN_NUM": BITS_IN_NUM}
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
    test_runner()