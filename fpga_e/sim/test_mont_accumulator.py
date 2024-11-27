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

# import sys
# sys.path.append("../../python_scripts")
# from montgomery_demo import calculate_bezout_constants

async def reset(rst,clk):
    """ Helper function to issue a reset signal to our module """
    rst.value = 1
    await ClockCycles(clk,3)
    rst.value = 0

 
def dispatch_blocks(value, num_blocks):
    while True:
        val = value
        for _ in range(num_blocks):
            yield val & (2**REGISTER_SIZE-1)
            val = val >> REGISTER_SIZE
        # print(f"Looping after {num_blocks}")

def dispatch_bit_blocks(value, num_blocks):
    while True:
        val = value
        for _ in range(num_blocks):
            yield val & 1
            val = val >> 1
        # print(f"Looping after {num_blocks}")
def extract_bottom_bits(value):
    return value %(2**REGISTER_SIZE)
def update_value(value):
    return value// (2**REGISTER_SIZE)


def check_for_block_request(dut, k_dispatcher, n_squared_dispatcher, n_dispatcher):
    if (int(dut.consumed_k_out.value) == 1):
        dut.k_in.value = next(k_dispatcher)
    if (int(dut.consumed_n_squared_out.value) ==1 ):
        dut.n_squared_in.value = next(n_squared_dispatcher)
    if (int(dut.consumed_n_out.value) == 1):
        dut.n_bit_in.value = next(n_dispatcher)
    

REGISTER_SIZE = 1024
OUT_NUM_BLOCKS = 4096//REGISTER_SIZE

BITS_IN_NUM = 4096

SMALL_N_OUT_BLOCKS = 2048


async def streamer_mock(dut,data_to_send, global_k_dispatcher, global_n_squared_dispatcher,global_n_dispactcher):
    rand_in = data_to_send
    for i in range(OUT_NUM_BLOCKS):
        dut.valid_in.value = 1
        dut.squarer_streamer_in = extract_bottom_bits(rand_in)
        rand_in = update_value(rand_in) 
        await AwareClockCycles(dut, global_k_dispatcher, global_n_squared_dispatcher,global_n_dispactcher)
        dut.valid_in.value = 0    


async def AwareClockCycles(dut,global_k_dispatcher,global_n_squared_dispatcher,global_n_dispactcher):
    check_for_block_request(dut, global_k_dispatcher, global_n_squared_dispatcher,global_n_dispactcher)
    await ClockCycles(dut.clk_in, 1)



@cocotb.test()
async def testing(dut):
    k = 143470092535370572884762559577261597060726098095130651285005957313214286020208846248841066413839665875461265127305468068675031009431615257076642373897015244136524563555490527907489468206900169957371718405066201235672090362478853663742336475964379108870711218822319915578568841927832446909576170206724004148662014335256366686051416432871380265066096266104993996707561049975588005673291226873645650089976222132906287395873762164927828399409677542706610136520339776715033573328301612875290174288048957888104513170905651338622165968798603889655834913370256159826940403775407788986108836704031341025569895498152471030201955294429901239594071770739717406269774068252071820981877376647344316707332724263561803448778502843622405588443134412694906949791848247581439427186190448488327675794671096010372437761696016989799470309941546670264823723175030798254161797471206863652908093391507702691498503852245524787840057862796014700934951893477680960594052882015846665426104688827909670722048223991884739539367655706233535869616672961157302847254190896924514009866479293385406880250829014263662616828841246401389608022822438266332289468984960397434107372764152486555063086719771617731206415603770119148562143343177455545346632889001702426541456831
    n_squared = 590422124689825055380819807609388189571256327875045759413123457324012204244904348160287525082997271790713457882660955619888946254261043203027771593298628441011612035265723835242026121235268765066944326490013942087806775580532770419185006727693836762421126549971166777350187227849036747874498748898200371278162103260529601535123784241275436339520934294087305771785057763906429748321306960060302877347805301757220204940169408640087558461307977499958542938818185362073916109749225361753465488257725527781630462231753011771059924172480693534542047579157001196799192378909460518139302358557373319671729492711810667118192183711386265644011686234954732739561715352966757275591394362051763747096082775428034331257483730208748244296931348278644467996131508327249311248703598496538092607531165259331139922697302096359403581744626882396938437309021732688016235359847356456980294356847006056239507114391778248012879303412205211396556204524145521662064393273536726990926093148343745926511722322805650194868790817814574744175510423873562280366546710025852968180416945163684882551407895812254630573660655532948916284348570078749620871743294686585436504822696481572626713064081970623249985910047616445949491493081152698162104745221931251546873892289
    r_mod = 453966756723327451310932903107236193008707921172338020971110025959941703726653108688539286852000286550176648831778307218098627183924750404235464494552736836934344941277986163098335468899114953247483743521842004138569543258864942326487327956650749855075681358734636926721096820891081861239969228885397657728524835716352186250823121388914824601078645159345517697517968932536629276694665439807411338193888533802665086546148829274346938272779834372680953536282003679275092307312449731914868362293307444306639088538230604598352008842733103291295140512676655554422126113936907607410923639743039025113133102962681527498831622794526979966814045600425354869060387481303440422610918806965914259579112709651887305161886555166376539717975810856815514794381891284302483022403232637552491665353114532223709860257021438157661641524434512509049255693101230707671547519101084159027118588827913766811064527985376568308501327633697704740370503818710919068383506698365054474837380075506521326548177473190440604600410956810242974274357031785687897962523763093580197370390623058161689194965401072658188946656801469492010332562304069635457540186509836396420834154951621553459189937220442843939740763168875065182111427700585335273985498582777088856280298047
    r_inverse = 81107639473872834862113160384587320505523681558308765561730460247589367636768099250959892926052788716221642552001139066815430567724344860583094243399736604136036937648928790764214416217951032207962309514754178084415447845641019335236679267431433119633245835662314870225975735960080986675999018544597031916700082197447731757331227648495676662127494563984609210881880262024711247896899271401123070539625781199441213299344824755371532711794411004593387207343171154694641025452736023477511533124921413766289410513644881125945554190822796304535623877818134706173653271145599695436068194617130535034171922426463589880815496060798780207388031145331065527728531271242491607203536076325279896483059756225312519985550978966934445095398386444334812097663868943921962473093468666185967862184613865127974750849105162079000335117677294111513038393051091619010878712049841141007755851239397551286050997004771575115216738471204786137390538447029669135710832418064692111189112621983088952873546418413707394233584124680888786573912063405304390478543315596591709252821498200463571641321827454439345060414450593247920183187777785231130217770494721592602618909655619784871745918950283071905258613686252409973737912390260494262666549989272981989941524185

    # r_mod = 19068383506698365054474837380075506521326548177473190440604600410956810242974274357031785687897962523763093580197370390623058161689194965401072658188946656801469492010332562304069635457540186509836396420834154951621553459189937220442843939740763168875065182111427700585335273985498582777088856280298047


   
    # write your test here!
	  # throughout your test, use "assert" statements to test for correct behavior
	  # replace the assertion below with useful statements
    # default parameters are DATA_WIDTH = 8, DATA_CLK_PERIOD = 100
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.valid_in.value = 0
    await reset(dut.rst_in,dut.clk_in)
    dut.valid_in.value = 0
    fake_n = (random.randint(1, 2**SMALL_N_OUT_BLOCKS-1)|1); 

    # makes multiplication aligned by waiting some time at the beginning
    await ClockCycles(dut.clk_in, 300)
    rand_constant = random.randint(1, 2**BITS_IN_NUM-1)
    rand_in = (rand_constant*r_mod)%n_squared
    wanted_loops = SMALL_N_OUT_BLOCKS
    # expected_res = (rand_in*rand_in*r_inverse)%n_squared
    # expected_res = ((rand_constant**4)*r_mod)%n_squared
    expected_res = rand_in

    global_k_dispatcher = dispatch_blocks(k, OUT_NUM_BLOCKS)
    global_n_squared_dispatcher = dispatch_blocks(n_squared, OUT_NUM_BLOCKS)
    global_n_dispactcher = dispatch_bit_blocks(fake_n, SMALL_N_OUT_BLOCKS)    
    dut.k_in.value = next(global_k_dispatcher)
    dut.n_squared_in.value = next(global_n_squared_dispatcher)
    dut.n_bit_in.value = next(global_n_dispactcher)
    await streamer_mock(dut, rand_in, global_k_dispatcher, global_n_squared_dispatcher,global_n_dispactcher)
    # initial_delay_between_sends = 1075
    # delay_between_sends = 1074
    initial_delay_between_sends = 303
    delay_between_sends = 302

    waiting_counter = initial_delay_between_sends # computed using cycles_between_sends signal
    loops = 0
    mul_data = 0
    mul_counter = 0
    new_fake_n = fake_n>>1
    # max_wait = 1000
    while (dut.valid_out.value !=1):
        if loops < wanted_loops-1:   # a num already has been sent
            if (waiting_counter == 0):
                loops = loops + 1
                # if (loops == wanted_loops): break
                rand_in =  (rand_in* rand_in * r_inverse)%n_squared
                if (new_fake_n& 1 == 1):
                    expected_res = (expected_res* rand_in * r_inverse)%n_squared
                new_fake_n = new_fake_n >> 1
                await streamer_mock(dut, rand_in, global_k_dispatcher, global_n_squared_dispatcher,global_n_dispactcher)
                waiting_counter = delay_between_sends
            else: 
                dut.valid_in.value = 0
                waiting_counter = waiting_counter - 1
            await AwareClockCycles(dut, global_k_dispatcher, global_n_squared_dispatcher,global_n_dispactcher)
        else:
            await AwareClockCycles(dut, global_k_dispatcher, global_n_squared_dispatcher,global_n_dispactcher)
    running_sum = 0
    for i in range(OUT_NUM_BLOCKS):
        running_sum += (int(dut.data_out.value))*(2**(REGISTER_SIZE*i))
        await AwareClockCycles(dut, global_k_dispatcher, global_n_squared_dispatcher,global_n_dispactcher)
    assert(running_sum == expected_res)
    # print(expected_res - (((rand_constant** fake_n) *r_mod)%n_squared))
    # await AwareClockCycles(dut, global_k_dispatcher, global_n_squared_dispatcher,global_n_dispactcher)
    


    
    
   
    
"""the code below should largely remain unchanged in structure, though the specific files and things
specified should get updated for different simulations.
"""
def test_runner():
    """Simulate using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "montgomery_reduce.sv",
               
               proj_path / "hdl" / "bram_blocks_rw.sv",
               proj_path / "hdl" / "evt_counter.sv",
               proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v",
               
               proj_path / "hdl" / "modulo_of_power.sv",
               
               proj_path / "hdl" / "fsm_multiplier.sv",
               proj_path / "hdl" / "mul_store.sv",
               proj_path / "hdl" / "accumulator.sv", 
               proj_path / "hdl" / "pipeliner.sv", 
               
               proj_path / "hdl" / "great_adder.sv", 
               
               proj_path / "hdl" / "right_shifter.sv", 
               
               proj_path / "hdl" / "running_comparator.sv", 
               
               proj_path / "hdl" / "great_subtractor.sv",

               proj_path / "hdl" / "mont_accumulator.sv"
               
               
               ] 
    build_test_args = ["-Wall"]#,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {"REGISTER_SIZE": REGISTER_SIZE, "BITS_IN_NUM": BITS_IN_NUM}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="mont_accumulator",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="mont_accumulator",
        test_module="test_mont_accumulator",
        test_args=run_test_args,
        waves=True
    )
 
if __name__ == "__main__":
    test_runner()