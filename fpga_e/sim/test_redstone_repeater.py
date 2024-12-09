import cocotb
from cocotb.triggers import Timer
import os
from pathlib import Path
import sys
import random
import math

from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,ReadWrite,with_timeout, First, Join
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

from random import getrandbits

async def reset(rst, clk):
    """ Helper function to issue a reset signal to our module """
    rst.value = 1
    await ClockCycles(clk, 3)
    rst.value = 0
    await ClockCycles(clk, 2)

async def NextValidRepeaterOut(dut, print_details=False):
    """
    Looks for the next cycle with valid data out from the multiplier (does not
    consider the current) cycle.
    """
    await ClockCycles(dut.clk_in, 1)
    ctr = 0
    while dut.data_valid_out.value != 1:
        assert ctr < MAX_CYCLES_BEFORE_DEADLOCK_DETECTED, "Repeater received a data_valid_out from repeater"
        if print_details:
            if (ctr % 10000) == 0:
                print("In here!")
        await ClockCycles(dut.clk_in, 1)
        ctr += 1

# async def ConsumeNextOutput(dut, print_details=False):
#     ctr = 0
#     while dut.done_writing.value != 1:
#         assert ctr < MAX_CYCLES_BEFORE_DEADLOCK_DETECTED, "Repeater never finished writing to BRAM"
#         if print_details:
#             if (ctr % 10000) == 0:
#                 print("In here!")
#         await ClockCycles(dut.clk_in, 1)
#         ctr += 1
#     dut.prev_data_consumed_in.

async def drive_data(dut, value_to_drive, print_details=False):
    if print_details:
        print(f"Initial result:\n{hex(value_to_drive)}\n")
    if print_details:
        print(f"NUM_BLOCKS_IN_NUM: {NUM_BLOCKS_IN_NUM}\n")

    for i in range(NUM_BLOCKS_IN_NUM):
        value_block = value_to_drive & REGISTER_SIZE_ALL_ONES
        if print_details:
            print(f"Block #{i + 1}: {hex(value_block)}")
        value_to_drive = value_to_drive >> REGISTER_SIZE
        dut.data_in.value = value_block
        dut.data_valid_in.value = 1
        await ClockCycles(dut.clk_in, 1)
    dut.data_valid_in.value = 0

def print_start_of_test_message(message_to_send):
    print(message_to_send)
    print(f"REGISTER_SIZE: {REGISTER_SIZE}")
    print(f"BITS_IN_NUM: {BITS_IN_NUM}")
    print(f"NUM_BLOCKS_IN_NUM: {NUM_BLOCKS_IN_NUM}")
    print(f"NUM_SPI_CON_CYCLES: {NUM_SPI_CON_CYCLES}")
    print(f"MAX_CYCLES_BEFORE_DEADLOCK_DETECTED: {MAX_CYCLES_BEFORE_DEADLOCK_DETECTED}\n\n")


@cocotb.test()
async def test_deterministic_one_input(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    # use helper function to assert reset signal
    dut.data_in.value = 0
    dut.data_valid_in.value = 0
    dut.prev_data_consumed_in.value = 1  # Assume spi is ready initially from the very start
    await reset(dut.rst_in, dut.clk_in)
    print_start_of_test_message("\n\nDeterministic Test 1 Starting!!\n\n")
    # print_details = True
    print_details = False
    
    input_value = 3

    await drive_data(dut, input_value, print_details)
    while dut.done_writing.value != 1:  # Wait for repeater to finish writing
        await ClockCycles(dut.clk_in, 1)
    dut.prev_data_consumed_in.value = 0

    for i in range(NUM_BLOCKS_IN_NUM):
        dut.prev_data_consumed_in.value = 0
        await NextValidRepeaterOut(dut, print_details)
        expected_block = input_value & REGISTER_SIZE_ALL_ONES
        input_value = input_value >> REGISTER_SIZE
        assert dut.data_valid_out == 1, f"Expected data_valid_out to remain high for {NUM_BLOCKS_IN_NUM} cycles. Failed on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        assert dut.data_out.value == expected_block, f"Expected data_out to be {expected_block}, got {dut.data_out.value} on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        await ClockCycles(dut.clk_in, MAX_CYCLES_BEFORE_DEADLOCK_DETECTED)
        dut.prev_data_consumed_in.value = 1
        await ClockCycles(dut.clk_in, 1)
        
    await ClockCycles(dut.clk_in, 1)
    assert dut.data_valid_out == 0, f"Expected data_valid_out to be low {NUM_BLOCKS_IN_NUM} cycles after it went high"
    await ClockCycles(dut.clk_in, 10)


@cocotb.test()
async def test_deterministic_two_inputs(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    # use helper function to assert reset signal
    dut.data_in.value = 0
    dut.data_valid_in.value = 0
    dut.prev_data_consumed_in.value = 1  # Assume spi is ready initially from the very start
    await reset(dut.rst_in, dut.clk_in)
    print_start_of_test_message("\n\nDeterministic Test 2 Starting!!\n\n")
    # print_details = True
    print_details = False
    

    input_value = 3

    await drive_data(dut, input_value, print_details)
    await NextValidRepeaterOut(dut, print_details)
    for i in range(NUM_BLOCKS_IN_NUM):
        expected_block = input_value & REGISTER_SIZE_ALL_ONES
        input_value = input_value >> REGISTER_SIZE
        assert dut.data_valid_out == 1, f"Expected data_valid_out to remain high for {NUM_BLOCKS_IN_NUM} cycles. Failed on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        assert dut.data_out.value == expected_block, f"Expected data_out to be {expected_block}, got {dut.data_out.value} on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        await ClockCycles(dut.clk_in, 1)
    await ClockCycles(dut.clk_in, 1)
    assert dut.data_valid_out == 0, f"Expected data_valid_out to be low {NUM_BLOCKS_IN_NUM} cycles after it went high"
    await ClockCycles(dut.clk_in, 10)

    input_value = 5
    await drive_data(dut, input_value, print_details)
    await NextValidRepeaterOut(dut, print_details)
    for i in range(NUM_BLOCKS_IN_NUM):
        expected_block = input_value & REGISTER_SIZE_ALL_ONES
        input_value = input_value >> REGISTER_SIZE
        assert dut.data_valid_out == 1, f"Expected data_valid_out to remain high for {NUM_BLOCKS_IN_NUM} cycles. Failed on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        assert dut.data_out.value == expected_block, f"Expected data_out to be {expected_block}, got {dut.data_out.value} on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        await ClockCycles(dut.clk_in, 1)
    await ClockCycles(dut.clk_in, 1)
    assert dut.data_valid_out == 0, f"Expected data_valid_out to be low {NUM_BLOCKS_IN_NUM} cycles after it went high"
    await ClockCycles(dut.clk_in, 10)


@cocotb.test()
async def test_random_three_inputs(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    # use helper function to assert reset signal
    dut.data_in.value = 0
    dut.data_valid_in.value = 0
    dut.prev_data_consumed_in.value = 1  # Assume spi is ready initially from the very start
    await reset(dut.rst_in, dut.clk_in)
    print_start_of_test_message("\n\Random Test 3 Starting!!\n\n")
    # print_details = True
    print_details = False
    
    input_value = 0
    for i in range(4096):
        coeff = random.randint(0, 1)
        input_value += coeff * 2**i

    await drive_data(dut, input_value, print_details)
    await NextValidRepeaterOut(dut, print_details)
    for i in range(NUM_BLOCKS_IN_NUM):
        expected_block = input_value & REGISTER_SIZE_ALL_ONES
        input_value = input_value >> REGISTER_SIZE
        assert dut.data_valid_out == 1, f"Expected data_valid_out to remain high for {NUM_BLOCKS_IN_NUM} cycles. Failed on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        assert dut.data_out.value == expected_block, f"Expected data_out to be {expected_block}, got {dut.data_out.value} on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        await ClockCycles(dut.clk_in, 1)
    await ClockCycles(dut.clk_in, 1)
    assert dut.data_valid_out == 0, f"Expected data_valid_out to be low {NUM_BLOCKS_IN_NUM} cycles after it went high"
    await ClockCycles(dut.clk_in, 10)

    input_value = 0
    for i in range(4096):
        coeff = random.randint(0, 1)
        input_value += coeff * 2**i

    await drive_data(dut, input_value, print_details)
    await NextValidRepeaterOut(dut, print_details)
    for i in range(NUM_BLOCKS_IN_NUM):
        expected_block = input_value & REGISTER_SIZE_ALL_ONES
        input_value = input_value >> REGISTER_SIZE
        assert dut.data_valid_out == 1, f"Expected data_valid_out to remain high for {NUM_BLOCKS_IN_NUM} cycles. Failed on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        assert dut.data_out.value == expected_block, f"Expected data_out to be {expected_block}, got {dut.data_out.value} on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        await ClockCycles(dut.clk_in, 1)
    await ClockCycles(dut.clk_in, 1)
    assert dut.data_valid_out == 0, f"Expected data_valid_out to be low {NUM_BLOCKS_IN_NUM} cycles after it went high"
    await ClockCycles(dut.clk_in, 10)

    input_value = 0
    for i in range(4096):
        coeff = random.randint(0, 1)
        input_value += coeff * 2**i

    await drive_data(dut, input_value, print_details)
    await NextValidRepeaterOut(dut, print_details)
    for i in range(NUM_BLOCKS_IN_NUM):
        expected_block = input_value & REGISTER_SIZE_ALL_ONES
        input_value = input_value >> REGISTER_SIZE
        assert dut.data_valid_out == 1, f"Expected data_valid_out to remain high for {NUM_BLOCKS_IN_NUM} cycles. Failed on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        assert dut.data_out.value == expected_block, f"Expected data_out to be {expected_block}, got {dut.data_out.value} on cycle {i+1} of {NUM_BLOCKS_IN_NUM}"
        await ClockCycles(dut.clk_in, 1)
    await ClockCycles(dut.clk_in, 1)
    assert dut.data_valid_out == 0, f"Expected data_valid_out to be low {NUM_BLOCKS_IN_NUM} cycles after it went high"
    await ClockCycles(dut.clk_in, 10)


REGISTER_SIZE = 512
REGISTER_SIZE_ALL_ONES = 2**REGISTER_SIZE - 1

BITS_IN_NUM = 4096
NUM_BLOCKS_IN_NUM = BITS_IN_NUM // REGISTER_SIZE

NUM_SPI_CON_CYCLES = 50
MAX_CYCLES_BEFORE_DEADLOCK_DETECTED = 5 * NUM_SPI_CON_CYCLES

top_level_name = "redstone_repeater"
test_name = "test_" + top_level_name
auxilary_module_names = [
]
auxilary_verilog_modules = [
    "xilinx_true_dual_port_read_first_2_clock_ram"
]
def test_tmds_runner():
    """Run the TMDS runner. Boilerplate code"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / f"{top_level_name}.sv"]
    for aux_module_name in auxilary_module_names:
        sources += [proj_path / "hdl" / f"{aux_module_name}.sv"]
    for aux_module_name in auxilary_verilog_modules:
        sources += [proj_path / "hdl" / f"{aux_module_name}.v"]
    build_test_args = ["-Wall"]
    parameters = {
        "REGISTER_SIZE": REGISTER_SIZE,
        "BITS_IN_NUM": BITS_IN_NUM,
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=top_level_name,
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel=top_level_name,
        test_module=test_name,
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_tmds_runner()