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

async def AwareClockCycles(dut, num_clk_cycles, k_chunk_idx, N_chunk_idx, print_details=False, cycle_ctr=[0]):
    """
    Used to await clock cycles while checking for when the next value of N_in or k_in
    needs to be updated.
    """
    for _ in range(num_clk_cycles):
        await ClockCycles(dut.clk_in, 1)
        if dut.consumed_k_out.value == 1:
            if print_details:
                print("Got in here 1!", cycle_ctr[0])
            dut.k_in.value = k_chunks[k_chunk_idx]
            k_chunk_idx = (k_chunk_idx + 1) % len(k_chunks)
        if dut.consumed_N_out.value == 1:
            if print_details:
                print("Got in here 2!", cycle_ctr[0])
            dut.N_in.value = N_chunks[N_chunk_idx]
            N_chunk_idx = (N_chunk_idx + 1) % len(N_chunks)
        cycle_ctr[0] += 1
    
    return k_chunk_idx, N_chunk_idx

async def NextValidMultiplierOut(dut, k_chunk_idx, N_chunk_idx, print_details=False):
    """
    Looks for the next cycle with valid data out from the multiplier (does not
    consider the current) cycle.
    """
    k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunk_idx, N_chunk_idx)
    ctr = 0
    while dut.multiplier_valid_out.value != 1:
        assert ctr < MAX_CYCLES_BEFORE_DEADLOCK_DETECTED, "Never received an expected multiplier"
        if print_details:
            if (ctr % 10000) == 0:
                print("In here 1!")
        k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunk_idx, N_chunk_idx, print_details)
        ctr += 1
    
    return k_chunk_idx, N_chunk_idx

async def NextValidReducerOut(dut, k_chunk_idx, N_chunk_idx, print_details=False):
    """
    Looks for the next cycle with valid data out from the reducer (does not
    consider the current) cycle.
    """
    k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunk_idx, N_chunk_idx, print_details)
    ctr = 0
    while dut.reducer_valid_out.value != 1:
        assert ctr < MAX_CYCLES_BEFORE_DEADLOCK_DETECTED, "Never received an expected reducer_valid_out"
        if print_details:
            if (ctr % 10000) == 0:
                print("In here 2!")
        k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunk_idx, N_chunk_idx, print_details)
        ctr += 1
    
    return k_chunk_idx, N_chunk_idx

async def drive_data(dut, a, k_chunk_idx, N_chunk_idx, print_details=False):
    current_reduced_modulo_result = (a * R) % N  # Initial result
    if print_details:
        print(f"Initial result:\n{hex(current_reduced_modulo_result)}")
    modulo_result_chunks_out = []  # Used to keep track of the chunks
    if print_details:
        print(f"NUM_BLOCKS_INTO_MULTIPLIER: {NUM_BLOCKS_INTO_MULTIPLIER}")
    for i in range(NUM_BLOCKS_INTO_MULTIPLIER):
        modulo_block_result = current_reduced_modulo_result & REGISTER_SIZE_ALL_ONES
        modulo_result_chunks_out.append(modulo_block_result)
        if print_details:
            print("Appended result:", hex(modulo_block_result))
        current_reduced_modulo_result = current_reduced_modulo_result >> REGISTER_SIZE
        k_chunk_idx, N_chunk_idx = await drive_data_block(dut, modulo_block_result, k_chunk_idx, N_chunk_idx, print_details)
        assert dut.squared_valid_out.value == 1, f"Expected valid out to be high 1-cycle after inputting data block {i} of {NUM_BLOCKS_OUT_OF_SQUARER} in the initial state"
        assert dut.reduced_square_out.value.integer == modulo_result_chunks_out[i], f"Expected {hex(modulo_result_chunks_out[i])} for block {i} of {NUM_BLOCKS_OUT_OF_SQUARER} in the initial state, got {hex(dut.reduced_square_out.value.integer)}"
    await finish_driving_data(dut)
    return k_chunk_idx, N_chunk_idx

async def drive_data_block(dut, reduced_modulo_block_in, k_chunk_idx, N_chunk_idx, print_details=False):
    """
    Drives a single chunk of data. data_valid_in must be manually set to 0 after
    all chunks are sent in whichever test is driving data.
    """
    dut.reduced_modulo_block_in.value = reduced_modulo_block_in
    dut.data_valid_in.value = 1
    k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunk_idx, N_chunk_idx, print_details)
    return k_chunk_idx, N_chunk_idx

async def finish_driving_data(dut):
    """
    Abstracts the setting of data_valid_in to 0 in case of future changes.
    """
    dut.data_valid_in.value = 0

async def verify_multiplier_outputs(dut, previous_montgomery_output, k_chunk_idx, N_chunk_idx, print_details=False):
    k_chunk_idx, N_chunk_idx = await NextValidMultiplierOut(dut, k_chunk_idx, N_chunk_idx, print_details)
    expected_multiplier_output = previous_montgomery_output**2
    if print_details:
        print(f"Full expected multiplier out:\n{hex(expected_multiplier_output)}")

    temp_expected_multiplier_output = expected_multiplier_output
    for i in range(NUM_BLOCKS_INTO_REDUCER):
        expected_multiplier_out_block = temp_expected_multiplier_output & REGISTER_SIZE_ALL_ONES
        temp_expected_multiplier_output = temp_expected_multiplier_output >> REGISTER_SIZE
        if print_details:
            print("Expected multiplier out block:", hex(expected_multiplier_out_block))

        assert dut.multiplier_valid_out.value == 1, f"Expected valid out to be high for {NUM_BLOCKS_INTO_MULTIPLIER} cycles after first valid high. Got low on cycle {i+1} of {NUM_BLOCKS_INTO_MULTIPLIER}"
        assert dut.multiplier_block_out.value.integer == expected_multiplier_out_block, f"Expected {hex(expected_multiplier_out_block)} for block {i+1} of {NUM_BLOCKS_INTO_MULTIPLIER} from the multiplier's output, got {hex(dut.multiplier_block_out.value.integer)}"

        k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunk_idx, N_chunk_idx, print_details)
    
    return k_chunk_idx, N_chunk_idx, expected_multiplier_output

async def verify_reducer_and_final_outputs(dut, previous_multiplier_output, k_chunk_idx, N_chunk_idx, print_details=False):
    k_chunk_idx, N_chunk_idx = await NextValidReducerOut(dut, k_chunk_idx, N_chunk_idx, print_details)
    expected_reducer_output = (previous_multiplier_output * R_INVERSE) % N
    if print_details:
        print(f"Full expected reducer out:\n{hex(expected_reducer_output)}")

    temp_expected_reducer_output = expected_reducer_output
    for i in range(NUM_BLOCKS_OUT_OF_SQUARER):
        expected_reducer_out_block = temp_expected_reducer_output & REGISTER_SIZE_ALL_ONES
        temp_expected_reducer_output = temp_expected_reducer_output >> REGISTER_SIZE
        if print_details:
            print("Expected reducer out block:", hex(expected_reducer_out_block))

        assert dut.reducer_valid_out.value == 1, f"Expected valid out to be high for {NUM_BLOCKS_INTO_REDUCER} cycles after first valid high. Got low on cycle {i+1} of {NUM_BLOCKS_INTO_REDUCER}"
        assert dut.reducer_block_out.value.integer == expected_reducer_out_block, f"Expected final output to be {hex(expected_reducer_out_block)} for block {i+1} of {NUM_BLOCKS_INTO_REDUCER} from the reducer's output, got {hex(dut.reducer_block_out.value.integer)}"
        assert dut.squared_valid_out.value == 1, f"Expected valid out to be high 1 cycle after reducer output was high for block {i} of {NUM_BLOCKS_OUT_OF_SQUARER}"
        assert dut.reduced_square_out.value.integer == expected_reducer_out_block, f"Expected final output to be {hex(expected_reducer_out_block)} for block {i} of {NUM_BLOCKS_OUT_OF_SQUARER} in the main state, got {hex(dut.reduced_square_out.value.integer)}"

        k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunk_idx, N_chunk_idx, print_details)
    
    return k_chunk_idx, N_chunk_idx, expected_reducer_output

async def verify_no_outputs_after_final_loop(dut, k_chunk_idx, N_chunk_idx, print_details=False):
    ctr = 0
    while ctr < MAX_CYCLES_BEFORE_DEADLOCK_DETECTED:
        k_chunk_idx, N_chunk_idx = await AwareClockCycles(dut, 1, k_chunk_idx, N_chunk_idx, print_details)
        assert dut.multiplier_valid_out.value != 1, "Expected the squarer's multiplier to no longer accept new inputs after the maximum-exponent loop iteration"
        ctr += 1
    
    return k_chunk_idx, N_chunk_idx

async def verify_num_bits_exact_iterations(dut, a, k_chunk_idx, N_chunk_idx, input_num, print_details=False):
    initial_montgomery_output = (a * R) % N
    k_chunk_idx, N_chunk_idx, prev_multiplier_output = await verify_multiplier_outputs(dut, initial_montgomery_output, k_chunk_idx, N_chunk_idx, print_details)
    k_chunk_idx, N_chunk_idx, prev_reducer_output = await verify_reducer_and_final_outputs(dut, prev_multiplier_output, k_chunk_idx, N_chunk_idx, print_details)
    print("Finished pass 1 (a)")
    for i in range(2, BITS_IN_NUM + 1):
        k_chunk_idx, N_chunk_idx, prev_multiplier_output = await verify_multiplier_outputs(dut, prev_reducer_output, k_chunk_idx, N_chunk_idx, print_details)
        k_chunk_idx, N_chunk_idx, prev_reducer_output = await verify_reducer_and_final_outputs(dut, prev_multiplier_output, k_chunk_idx, N_chunk_idx, print_details)
        print(f"Finished pass {i} (a^(2^{i}))")

    k_chunk_idx, N_chunk_idx = await verify_no_outputs_after_final_loop(dut, k_chunk_idx, N_chunk_idx, print_details)
    print(f"Finished dealing with input #{input_num}")
    return k_chunk_idx, N_chunk_idx

def print_start_of_test_message(message_to_send):
    print(message_to_send)
    print(f"REGISTER_SIZE: {REGISTER_SIZE}")
    print(f"BITS_IN_NUM: {BITS_IN_NUM}")
    print(f"HIGHEST_EXPONENT: {HIGHEST_EXPONENT}")
    print(f"R: {R_EXPONENT}")


@cocotb.test()
async def test_deterministic_one_input(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    # use helper function to assert reset signal
    dut.N_in.value = 0
    dut.k_in.value = 0
    dut.reduced_modulo_block_in.value = 0
    dut.data_valid_in.value = 0
    await reset(dut.rst_in, dut.clk_in)
    print_start_of_test_message("\n\nDeterministic Test 1 Starting!!\n\n")
    # print_details = True
    print_details = False
    
    dut.N_in = N_chunks[0]  # N_in and k_in should be initialized to their first chunks.
    dut.k_in = k_chunks[0]

    N_chunk_idx = 1  # Represents the idx of the next N-chunk to pass into the squarer stream; by default, index 0 is already passed in
    k_chunk_idx = 1  # Same as above ^
    
    input_num = 1
    a = 3  # Randomly selected number by me, not meaningful in anyway
    k_chunk_idx, N_chunk_idx = await drive_data(dut, a, k_chunk_idx, N_chunk_idx, print_details)
    
    k_chunk_idx, N_chunk_idx = await verify_num_bits_exact_iterations(dut, a, k_chunk_idx, N_chunk_idx, input_num, print_details)


@cocotb.test()
async def test_deterministic_two_inputs(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    # use helper function to assert reset signal
    dut.N_in.value = 0
    dut.k_in.value = 0
    dut.reduced_modulo_block_in.value = 0
    dut.data_valid_in.value = 0
    await reset(dut.rst_in, dut.clk_in)
    print_start_of_test_message("\n\nDeterministic Test 2 Starting!!\n\n")
    # print_details = True
    print_details = False
    
    dut.N_in = N_chunks[0]  # N_in and k_in should be initialized to their first chunks.
    dut.k_in = k_chunks[0]

    N_chunk_idx = 1  # Represents the idx of the next N-chunk to pass into the squarer stream; by default, index 0 is already passed in
    k_chunk_idx = 1  # Same as above ^
    
    input_num = 1
    a = 3  # Randomly selected number by me, not meaningful in anyway
    k_chunk_idx, N_chunk_idx = await drive_data(dut, a, k_chunk_idx, N_chunk_idx, print_details)
    
    k_chunk_idx, N_chunk_idx = await verify_num_bits_exact_iterations(dut, a, k_chunk_idx, N_chunk_idx, input_num, print_details)

    input_num += 1
    a = 11  # Randomly selected number by me, not meaningful in anyway
    k_chunk_idx, N_chunk_idx = await drive_data(dut, a, k_chunk_idx, N_chunk_idx, print_details)
    
    k_chunk_idx, N_chunk_idx = await verify_num_bits_exact_iterations(dut, a, k_chunk_idx, N_chunk_idx, input_num, print_details)


@cocotb.test()
async def test_random_three_inputs(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    # use helper function to assert reset signal
    dut.N_in.value = 0
    dut.k_in.value = 0
    dut.reduced_modulo_block_in.value = 0
    dut.data_valid_in.value = 0
    await reset(dut.rst_in, dut.clk_in)
    print_start_of_test_message("\n\Random Test 3 Starting!!\n\n")
    # print_details = True
    print_details = False
    
    dut.N_in = N_chunks[0]  # N_in and k_in should be initialized to their first chunks.
    dut.k_in = k_chunks[0]

    N_chunk_idx = 1  # Represents the idx of the next N-chunk to pass into the squarer stream; by default, index 0 is already passed in
    k_chunk_idx = 1  # Same as above ^
    
    input_num = 1
    a = random.randint(1, 2**2048 - 1)
    k_chunk_idx, N_chunk_idx = await drive_data(dut, a, k_chunk_idx, N_chunk_idx, print_details)
    
    k_chunk_idx, N_chunk_idx = await verify_num_bits_exact_iterations(dut, a, k_chunk_idx, N_chunk_idx, input_num, print_details)

    input_num += 1
    a = random.randint(1, 2**2048 - 1)
    k_chunk_idx, N_chunk_idx = await drive_data(dut, a, k_chunk_idx, N_chunk_idx, print_details)
    
    k_chunk_idx, N_chunk_idx = await verify_num_bits_exact_iterations(dut, a, k_chunk_idx, N_chunk_idx, input_num, print_details)

    input_num += 1
    a = random.randint(1, 2**2048 - 1)
    k_chunk_idx, N_chunk_idx = await drive_data(dut, a, k_chunk_idx, N_chunk_idx, print_details)
    
    k_chunk_idx, N_chunk_idx = await verify_num_bits_exact_iterations(dut, a, k_chunk_idx, N_chunk_idx, input_num, print_details)


REGISTER_SIZE = 1024
REGISTER_SIZE_ALL_ONES = 2**REGISTER_SIZE - 1

BITS_IN_NUM = 2048
BITS_IN_REDUCER_OUT = 2 * BITS_IN_NUM
BITS_IN_N_AND_K = 2 * BITS_IN_NUM

NUM_BLOCKS_OUT_OF_SQUARER = BITS_IN_REDUCER_OUT // REGISTER_SIZE
NUM_BLOCKS_INTO_MULTIPLIER = NUM_BLOCKS_OUT_OF_SQUARER
NUM_BLOCKS_INTO_REDUCER = 2 * NUM_BLOCKS_INTO_MULTIPLIER
NUM_BLOCKS_IN_N_AND_K = BITS_IN_N_AND_K // REGISTER_SIZE

MAX_CYCLES_BEFORE_DEADLOCK_DETECTED = 2*100_000

HIGHEST_EXPONENT = BITS_IN_NUM

R_EXPONENT = 4096
R = 2**R_EXPONENT
# Gracias Luis
R_INVERSE = 81107639473872834862113160384587320505523681558308765561730460247589367636768099250959892926052788716221642552001139066815430567724344860583094243399736604136036937648928790764214416217951032207962309514754178084415447845641019335236679267431433119633245835662314870225975735960080986675999018544597031916700082197447731757331227648495676662127494563984609210881880262024711247896899271401123070539625781199441213299344824755371532711794411004593387207343171154694641025452736023477511533124921413766289410513644881125945554190822796304535623877818134706173653271145599695436068194617130535034171922426463589880815496060798780207388031145331065527728531271242491607203536076325279896483059756225312519985550978966934445095398386444334812097663868943921962473093468666185967862184613865127974750849105162079000335117677294111513038393051091619010878712049841141007755851239397551286050997004771575115216738471204786137390538447029669135710832418064692111189112621983088952873546418413707394233584124680888786573912063405304390478543315596591709252821498200463571641321827454439345060414450593247920183187777785231130217770494721592602618909655619784871745918950283071905258613686252409973737912390260494262666549989272981989941524185
k = 143470092535370572884762559577261597060726098095130651285005957313214286020208846248841066413839665875461265127305468068675031009431615257076642373897015244136524563555490527907489468206900169957371718405066201235672090362478853663742336475964379108870711218822319915578568841927832446909576170206724004148662014335256366686051416432871380265066096266104993996707561049975588005673291226873645650089976222132906287395873762164927828399409677542706610136520339776715033573328301612875290174288048957888104513170905651338622165968798603889655834913370256159826940403775407788986108836704031341025569895498152471030201955294429901239594071770739717406269774068252071820981877376647344316707332724263561803448778502843622405588443134412694906949791848247581439427186190448488327675794671096010372437761696016989799470309941546670264823723175030798254161797471206863652908093391507702691498503852245524787840057862796014700934951893477680960594052882015846665426104688827909670722048223991884739539367655706233535869616672961157302847254190896924514009866479293385406880250829014263662616828841246401389608022822438266332289468984960397434107372764152486555063086719771617731206415603770119148562143343177455545346632889001702426541456831
N = 590422124689825055380819807609388189571256327875045759413123457324012204244904348160287525082997271790713457882660955619888946254261043203027771593298628441011612035265723835242026121235268765066944326490013942087806775580532770419185006727693836762421126549971166777350187227849036747874498748898200371278162103260529601535123784241275436339520934294087305771785057763906429748321306960060302877347805301757220204940169408640087558461307977499958542938818185362073916109749225361753465488257725527781630462231753011771059924172480693534542047579157001196799192378909460518139302358557373319671729492711810667118192183711386265644011686234954732739561715352966757275591394362051763747096082775428034331257483730208748244296931348278644467996131508327249311248703598496538092607531165259331139922697302096359403581744626882396938437309021732688016235359847356456980294356847006056239507114391778248012879303412205211396556204524145521662064393273536726990926093148343745926511722322805650194868790817814574744175510423873562280366546710025852968180416945163684882551407895812254630573660655532948916284348570078749620871743294686585436504822696481572626713064081970623249985910047616445949491493081152698162104745221931251546873892289

N_chunks = []  # The chunks of N (fixed) that will be cycled through
k_chunks = []  # Same as above ^


temp_N = N
temp_k = k
for i in range(1, NUM_BLOCKS_IN_N_AND_K + 1):
    current_N_block = temp_N & REGISTER_SIZE_ALL_ONES
    N_chunks.append(current_N_block)
    temp_N = temp_N >> REGISTER_SIZE

    current_k_block = temp_k & REGISTER_SIZE_ALL_ONES
    k_chunks.append(current_k_block)
    temp_k = temp_k >> REGISTER_SIZE

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
        "R": R_EXPONENT
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