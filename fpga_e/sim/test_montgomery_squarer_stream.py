import cocotb
from cocotb.triggers import Timer
import os
from pathlib import Path
import sys
import random

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

async def AwareClockCycles(dut, num_clk_cycles, k_chunks, k_chunk_idx, N_chunks, N_chunk_idx, cycle_ctr=[0]):
    """
    Used to await clock cycles while checking for when the next value of N_in or k_in
    needs to be updated.
    """
    for _ in range(num_clk_cycles):
        await ClockCycles(dut.clk_in, 1)
        # print("Sup.", dut.consumed_k_out, dut.consumed_N_out)
        if dut.consumed_k_out.value == 1:
            print("Got in here 1!", cycle_ctr[0])
            dut.k_in.value = k_chunks[k_chunk_idx]
            k_chunk_idx = (k_chunk_idx + 1) % len(k_chunks)
        if dut.consumed_N_out.value == 1:
            print("Got in here 2!", cycle_ctr[0])
            dut.N_in.value = N_chunks[N_chunk_idx]
            N_chunk_idx = (N_chunk_idx + 1) % len(N_chunks)
        cycle_ctr[0] += 1
        # if cycle_ctr[0] % 10 == 0:
        #     print("Cycle:", cycle_ctr[0])
    
    return k_chunk_idx, N_chunk_idx

async def NextValidDataOut(dut, k_chunks, k_chunk_idx, N_chunks, N_chunk_idx):
    """
    Looks for the next cycle with valid data out (does not consider the current)
    cycle.
    """
    k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunks, k_chunk_idx, N_chunks, N_chunk_idx)
    ctr = 0
    while dut.squared_valid_out.value != 1:
        # if (ctr % 10000) == 0:
        #     print("In here!")
        # if ctr == 40000:
        #     break
        k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunks, k_chunk_idx, N_chunks, N_chunk_idx)
        ctr += 1
    
    return k_chunk_idx, N_chunk_idx

async def drive_data(dut, reduced_modulo_block_in, k_chunks, k_chunk_idx, N_chunks, N_chunk_idx):
    """
    Drives a single chunk of data. data_valid_in must be manually set to 0 after
    all chunks are sent in whichever test is driving data.
    """
    dut.reduced_modulo_block_in.value = reduced_modulo_block_in
    dut.data_valid_in.value = 1
    k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunks, k_chunk_idx, N_chunks, N_chunk_idx)
    return k_chunk_idx, N_chunk_idx

async def finish_driving_data(dut):
    """
    Abstracts the setting of data_valid_in to 0 in case of future changes.
    """
    dut.data_valid_in.value = 0

def verify_values_reset(dut):
    """
    Ideally we will generalize the value-testing in this function, making
    the tests more readable and DRY.
    """
    pass  # TODO

@cocotb.test()
async def test_deterministic(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    # use helper function to assert reset signal
    dut.N_in.value = 0
    dut.k_in.value = 0
    dut.reduced_modulo_block_in.value = 0
    dut.data_valid_in.value = 0
    await reset(dut.rst_in, dut.clk_in)
    print("\n\Deterministic Test Starting!!\n\n")

    a = 3  # Randomly selected number by me, not meaningful in anyway
    N = 0
    N_chunks = []  # The chunks of N (fixed) that will be cycled through
    N_chunk_idx = 1  # Represents the idx of the next N-chunk to pass into the squarer stream; by default, index 0 is already passed in
    k_chunks = []  # Same as above ^
    k_chunk_idx = 1
    for i in range(1, NUM_BLOCKS + 1):
        N = N*(2**REGISTER_SIZE) + i  # Multiplying by 2**REGISTER_SIZE is equivalent to right-shifting by REGISTER_SIZE.
        N_chunks.append(i)
        k_chunks.append(N_chunks[i - 1] + NUM_BLOCKS)
    
    dut.N_in = N_chunks[0]  # N_in and k_in should be initialized to their first chunks.
    dut.k_in = k_chunks[0]
    
    current_reduced_modulo_result = (a * R) % N  # Initial result
    modulo_result_chunks_out = []  # Used to keep track of the chunks
    for i in range(1, NUM_BLOCKS + 1):
        modulo_block_result = current_reduced_modulo_result & 0xFFFF_FFFF
        modulo_result_chunks_out.append(modulo_block_result)
        current_reduced_modulo_result >> (i * REGISTER_SIZE)
        # initial_reduced_modulo_result // REGISTER_SIZE  // TODO - Uncomment this in case right shifting is scuffed.
        k_chunk_idx, N_chunk_idx = await drive_data(dut, modulo_block_result, k_chunks, k_chunk_idx, N_chunks, N_chunk_idx)
        if i != 1:
            assert dut.squared_valid_out.value == 1, f"Expected valid out to be high 1-cycle after inputting data block {i-1} of {NUM_BLOCKS} in the initial state"
            assert dut.reduced_square_out == modulo_result_chunks_out[i-2], f"Expected {modulo_result_chunks_out[i-2]} for block {i-1} of {NUM_BLOCKS} in the initial state, got {dut.reduced_square_out}"
    k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunks, k_chunk_idx, N_chunks, N_chunk_idx)
    assert dut.squared_valid_out.value == 1, "Expected valid out to be high 1-cycle after inputting the last data block in the initial state"
    assert dut.reduced_square_out.value.integer == modulo_result_chunks_out[-1], f"Expected {hex(modulo_result_chunks_out[-1])} for the last block of the initial state, got {hex(dut.reduced_square_out.value.integer)}"
    await finish_driving_data(dut)
    
    k_chunk_idx, N_chunk_idx = await NextValidDataOut(dut, k_chunks, k_chunk_idx, N_chunks, N_chunk_idx)
    current_reduced_modulo_result = (a**2 * R) % N
    print("Full expected out:", hex(current_reduced_modulo_result))
    for i in range(NUM_BLOCKS):
        modulo_block_result = current_reduced_modulo_result & 0xFFFF_FFFF
        current_reduced_modulo_result >> (i * REGISTER_SIZE)
        # initial_reduced_modulo_result // REGISTER_SIZE  // TODO - Uncomment this in case right shifting is scuffed.
        assert dut.squared_valid_out.value == 1, f"Expected valid out to be high for {NUM_BLOCKS} cycles after first valid high. Got low on cycle {i+1} of {NUM_BLOCKS}"
        assert dut.reduced_square_out.value.integer == modulo_block_result, f"Expected {hex(modulo_block_result)} for block {i+1} of {NUM_BLOCKS} in the initial state, got {hex(dut.reduced_square_out.value.integer)}"
        k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunks, k_chunk_idx, N_chunks, N_chunk_idx)
    k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 5, k_chunks, k_chunk_idx, N_chunks, N_chunk_idx)


# @cocotb.test()
# async def test_random(dut):
#     cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
#     # use helper function to assert reset signal
#     dut.N_in.value = 0
#     dut.k_in.value = 0
#     dut.reduced_modulo_block_in.value = 0
#     dut.data_valid_in.value = 0
#     await reset(dut.rst_in, dut.clk_in)


REGISTER_SIZE = 32
BITS_IN_NUM = 2048
R = 4096
BITS_IN_OUT = 2 * BITS_IN_NUM
NUM_BLOCKS = 2 * BITS_IN_OUT // REGISTER_SIZE
top_level_name = "montgomery_squarer_stream"
test_name = "test_" + top_level_name
auxilary_module_names = [
    "fsm_multiplier",
    "mul_store",
    "accumulator",
    "montgomery_reduce",
    "modulo_of_power",
    "bram_blocks_rw",
    "pipeliner",
    "great_adder",
    "right_shifter",
    "running_comparator",
    "great_subtractor",
    "evt_counter"
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
        "R": R
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