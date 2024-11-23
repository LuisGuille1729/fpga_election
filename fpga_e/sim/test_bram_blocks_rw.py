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
 
async def send(dut, block_value):
    dut.valid_in.value = 1 
    dut.block_in.value = block_value
    # print(dut.valid_out.value)
    await ClockCycles(dut.clk_in, 1)
    
    
async def delay(dut, time, addRandomDelay=True):
    dut.valid_in.value = 0
    await ClockCycles(dut.clk_in, time)
    if addRandomDelay:
        await ClockCycles(dut.clk_in, random.randint(0, 1))
 
@cocotb.test()
async def first_test(dut):
    """ First cocotb test?"""
    # write your test here!
	  # throughout your test, use "assert" statements to test for correct behavior
	  # replace the assertion below with useful statements
    # default parameters are DATA_WIDTH = 8, DATA_CLK_PERIOD = 100
    dut._log.info("Starting...")
    # Start clock with 10ns period (100MHz frequency)
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start()) 

    # Test rst_in
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 10)
    
    dut.rst_in.value = 0
    dut.write_next_block_valid_in.value = 0
    dut.read_next_block_valid_in.value = 0
    
    await ClockCycles(dut.clk_in, 1)
    
    # Write N
    bigN = 590422124689825055380819807609388189571256327875045759413123457324012204244904348160287525082997271790713457882660955619888946254261043203027771593298628441011612035265723835242026121235268765066944326490013942087806775580532770419185006727693836762421126549971166777350187227849036747874498748898200371278162103260529601535123784241275436339520934294087305771785057763906429748321306960060302877347805301757220204940169408640087558461307977499958542938818185362073916109749225361753465488257725527781630462231753011771059924172480693534542047579157001196799192378909460518139302358557373319671729492711810667118192183711386265644011686234954732739561715352966757275591394362051763747096082775428034331257483730208748244296931348278644467996131508327249311248703598496538092607531165259331139922697302096359403581744626882396938437309021732688016235359847356456980294356847006056239507114391778248012879303412205211396556204524145521662064393273536726990926093148343745926511722322805650194868790817814574744175510423873562280366546710025852968180416945163684882551407895812254630573660655532948916284348570078749620871743294686585436504822696481572626713064081970623249985910047616445949491493081152698162104745221931251546873892289
    N2 = bigN
    for i in range(128):
        dut.write_next_block_valid_in.value = 1
        dut.write_block_in.value = N2 & 0xFFFF_FFFF
        await ClockCycles(dut.clk_in, 1)
        N2 = N2 >> 32
    
    dut.write_next_block_valid_in.value = 0
    await ClockCycles(dut.clk_in, 1)

    # Read values of N back
    for i in range(128):
        dut.read_next_block_valid_in.value = 1
        await ClockCycles(dut.clk_in, 1)
        
        if (i > 1):
            assert dut.read_block_pipe2_valid_out.value == 1
            assert dut.read_block_out.value == bigN & 0xFFFF_FFFF, f"On i={i}, got {int(dut.read_block_out.value)}. Expected {bigN & 0xFFFF_FFFF}"
            bigN = bigN >> 32

    dut.read_next_block_valid_in.value = 0

    await ClockCycles(dut.clk_in, 10)


    # Write K
    K = 143470092535370572884762559577261597060726098095130651285005957313214286020208846248841066413839665875461265127305468068675031009431615257076642373897015244136524563555490527907489468206900169957371718405066201235672090362478853663742336475964379108870711218822319915578568841927832446909576170206724004148662014335256366686051416432871380265066096266104993996707561049975588005673291226873645650089976222132906287395873762164927828399409677542706610136520339776715033573328301612875290174288048957888104513170905651338622165968798603889655834913370256159826940403775407788986108836704031341025569895498152471030201955294429901239594071770739717406269774068252071820981877376647344316707332724263561803448778502843622405588443134412694906949791848247581439427186190448488327675794671096010372437761696016989799470309941546670264823723175030798254161797471206863652908093391507702691498503852245524787840057862796014700934951893477680960594052882015846665426104688827909670722048223991884739539367655706233535869616672961157302847254190896924514009866479293385406880250829014263662616828841246401389608022822438266332289468984960397434107372764152486555063086719771617731206415603770119148562143343177455545346632889001702426541456831
    K2 = K
    for i in range(128):
        dut.write_next_block_valid_in.value = 1
        dut.write_block_in.value = K2 & 0xFFFF_FFFF
        await ClockCycles(dut.clk_in, 1)
        K2 = K2 >> 32
    
    dut.write_next_block_valid_in.value = 0
    await ClockCycles(dut.clk_in, 1)

    # Read values of N back
    for i in range(128):
        dut.read_next_block_valid_in.value = 1
        await ClockCycles(dut.clk_in, 1)
        
        if (i > 1):
            assert dut.read_block_pipe2_valid_out.value == 1
            assert dut.read_block_out.value == K & 0xFFFF_FFFF, f"On i={i}, got {int(dut.read_block_out.value)}. Expected {K & 0xFFFF_FFFF}"
            K = K >> 32

    dut.read_next_block_valid_in.value = 0

    await ClockCycles(dut.clk_in, 10)
    
    
 
"""the code below should largely remain unchanged in structure, though the specific files and things
specified should get updated for different simulations.
"""
def test_runner():
    """Simulate using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "bram_blocks_rw.sv",
               proj_path / "hdl" / "evt_counter.sv",
               proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v"] #grow/modify this as needed.
    build_test_args = ["-Wall"]#,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="bram_blocks_rw",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="bram_blocks_rw",
        test_module="test_bram_blocks_rw",
        test_args=run_test_args,
        waves=True
    )
 
if __name__ == "__main__":
    test_runner()