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



def dispatch_blocks(value, num_blocks, infinite=True):
    while True:
        val = value
        for _ in range(num_blocks):
            yield val & (2**REGISTER_SIZE-1)
            val = val >> REGISTER_SIZE
        # print(f"Looping after {num_blocks}")
        
        if infinite is False:
            break

REGISTER_SIZE = 32
NUM_BLOCKS_IN = 128
BITS_EXPONENT = 6080
NUM_BLOCKS_OUT = 64

# REGISTER_SIZE = 64
# NUM_BLOCKS_IN = 64
# BITS_EXPONENT = 6080
# NUM_BLOCKS_OUT = 32

# For REGISTER_SIZE > 64 need to change mult_inv
        
# Our divisor:
n = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767
# Our mult_inv:
mult_inv = 75299540386319832354160211189449715021739337572771619406034950168942320910896840776854970153328317531817236329179406815725689583186853726176905598397390492914804344618125333378787729278321822183396226413688586713590845583585245299283933344483047261329067452218606922201317313088493682065927111964296840109381400532732683401088837160650764546687277777040847177422585670354027880681475100346339193036529984948819170330947279644998579025953595192781811896396668196204841894496431652498822227328376699452763141358399571873467329760181720536465116539495136425372850124300208989594033363546950075573838411453104518901916641298228905697185061669962474356751283187733596877822574754600206684623527575365198056857919390629210755372526149688690285459057377006634195232860727511107656767724680749521238380812355199943718493222164182270400520542015300202052832180915193602335560545451968421551161541355504581254594258915106723392088252063735102087361162514814839309376422247892492224101277591803585351248659373063887685892589143245270972989148291111483798381921903845592141897141997014415163682658432361342924395636546114735726870516464138489520449436370149940037433753071794727253607057736971930561852387076048984088400948076
mult_inv_dispatcher = dispatch_blocks(mult_inv, NUM_BLOCKS_IN, True)
        
async def test_division(dut, dividend):
    
    dividend_dispatcher = dispatch_blocks(dividend, NUM_BLOCKS_IN, False)
    expected_dispatcher = dispatch_blocks(dividend//n, NUM_BLOCKS_OUT, False)
    
    total_cycles = 0
    dut.valid_in.value = 1
    for i in range(NUM_BLOCKS_IN):
        dut.x_block_in.value = next(dividend_dispatcher)
        # dut.mult_inv_constant_block_in.value = next(mult_inv_dispatcher)
        await ClockCycles(dut.clk_in, 1)
        total_cycles += 1
    dut.valid_in.value = 0
    
    # await ClockCycles(dut.clk_in, 20000)
    
    while dut.valid_out.value == 0:
        await ClockCycles(dut.clk_in, 1)
        total_cycles += 1
        
    out_cycle = 0
    while dut.valid_out.value == 1:
        # print(out_cycle, hex(dut.data_block_out.value))
        assert dut.data_block_out.value == next(expected_dispatcher), f"[{out_cycle}] Wrong value {dut.valid_out.value} with dividend {dividend}"
        await ClockCycles(dut.clk_in, 1)
        out_cycle += 1
        total_cycles += 1
        
    assert out_cycle == NUM_BLOCKS_OUT

    print(f"Calculated output in {total_cycles} cycles")
        
    
        
@cocotb.test()
async def testing(dut):   
   
   
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
    
    x = random.randint(0, 2**4096-1)
    await test_division(dut, x)
    await ClockCycles(dut.clk_in, 0) # Need to have these additional two cycles
    x = random.randint(0, 2**4096-1)
    await test_division(dut, x)
    
    for i in range (1000):
        exp = random.choice([
            random.randint(0, 16), 
            random.randint(0, 1024),
            random.randint(500, 2024),
            random.randint(2000, 4000),
            random.randint(4000, 4096),
            4096])
        x = random.randint(0, 2**exp-1)
        print(f"Calculating division of {x.bit_length()}-bits number by n. Test #{i}")
        await test_division(dut, x)
    
    
    
    

"""the code below should largely remain unchanged in structure, though the specific files and things
specified should get updated for different simulations.
"""
def test_runner():
    """Simulate using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "fixed_divider.sv",
               proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v",
               proj_path / "hdl" / "inverse_multiplier.sv",] 
    build_test_args = ["-Wall"]#,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {"REGISTER_SIZE": REGISTER_SIZE, "NUM_BLOCKS_IN": NUM_BLOCKS_IN, "BITS_EXPONENT": BITS_EXPONENT, "NUM_BLOCKS_OUT": NUM_BLOCKS_OUT}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="fixed_divider",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="fixed_divider",
        test_module="test_fixed_divider",
        test_args=run_test_args,
        waves=True
    )
 
if __name__ == "__main__":
    test_runner()