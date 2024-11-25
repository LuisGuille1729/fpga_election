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
 
async def send_block(dut, blockA_value, blockB_value):
    dut.valid_in.value = 1 
    dut.block_numA_in.value = blockA_value
    dut.block_numB_in.value = blockB_value
    await ClockCycles(dut.clk_in, 1)
    
    
async def delay(dut, time, addRandomDelay=False):
    dut.valid_in.value = 0
    await ClockCycles(dut.clk_in, time)
    if addRandomDelay:
        await ClockCycles(dut.clk_in, random.randint(0, 1))
 
async def comparison_test(dut, A, B):
    print(f"Compare: A is {A.bit_length()}-bits, B is {B.bit_length()}-bits.")
    if (A == B):
        expected = 0b11
    elif (A < B):
        expected = 0b01
    else:
        expected = 0b10
    
    
    for count in range(128):
        A_in = A & (0xFFFF_FFFF)
        B_in = B & (0xFFFF_FFFF)
        await send(dut, A_in, B_in)
        A = A >> 32
        B = B >> 32
        
        if count != 127:
            assert dut.end_comparison_signal_out.value == 0
        assert dut.block_count.value == count    
    
    assert dut.end_comparison_signal_out.value == 1
    assert int(dut.comparison_result_out.value) == expected
 
# def get_constant_block(const, block_id):
#     return (const >> (block_id*32)) & 0xFFFF_FFFF

def dispatch_blocks(value, num_blocks):
    while True:
        val = value
        for _ in range(num_blocks):
            yield val & 0xFFFF_FFFF
            val = val >> 32

def check_for_block_request(dut, k_dispatcher, N_dispatcher):
    if (dut.consumed_k_out.value):
        dut.k_constant_block_in.value = next(k_dispatcher)
    if (dut.consumed_N_out.value):
        dut.modN_constant_block_in.value = next(N_dispatcher)
    # return (next(k_dispatcher), next(N_dispatcher))

@cocotb.test()
async def first_test(dut):
    
    k = 143470092535370572884762559577261597060726098095130651285005957313214286020208846248841066413839665875461265127305468068675031009431615257076642373897015244136524563555490527907489468206900169957371718405066201235672090362478853663742336475964379108870711218822319915578568841927832446909576170206724004148662014335256366686051416432871380265066096266104993996707561049975588005673291226873645650089976222132906287395873762164927828399409677542706610136520339776715033573328301612875290174288048957888104513170905651338622165968798603889655834913370256159826940403775407788986108836704031341025569895498152471030201955294429901239594071770739717406269774068252071820981877376647344316707332724263561803448778502843622405588443134412694906949791848247581439427186190448488327675794671096010372437761696016989799470309941546670264823723175030798254161797471206863652908093391507702691498503852245524787840057862796014700934951893477680960594052882015846665426104688827909670722048223991884739539367655706233535869616672961157302847254190896924514009866479293385406880250829014263662616828841246401389608022822438266332289468984960397434107372764152486555063086719771617731206415603770119148562143343177455545346632889001702426541456831
    n_squared = 590422124689825055380819807609388189571256327875045759413123457324012204244904348160287525082997271790713457882660955619888946254261043203027771593298628441011612035265723835242026121235268765066944326490013942087806775580532770419185006727693836762421126549971166777350187227849036747874498748898200371278162103260529601535123784241275436339520934294087305771785057763906429748321306960060302877347805301757220204940169408640087558461307977499958542938818185362073916109749225361753465488257725527781630462231753011771059924172480693534542047579157001196799192378909460518139302358557373319671729492711810667118192183711386265644011686234954732739561715352966757275591394362051763747096082775428034331257483730208748244296931348278644467996131508327249311248703598496538092607531165259331139922697302096359403581744626882396938437309021732688016235359847356456980294356847006056239507114391778248012879303412205211396556204524145521662064393273536726990926093148343745926511722322805650194868790817814574744175510423873562280366546710025852968180416945163684882551407895812254630573660655532948916284348570078749620871743294686585436504822696481572626713064081970623249985910047616445949491493081152698162104745221931251546873892289

    # T 8192-bits long
    # T = random.randint(2**8191, 2**8192-1)
    T = 668046964085213323677521973090209666948265322575032540699613055124432667085172110660147195335909942987381575932157651701154744675200694478842057168218319856257092368160970530081040347415486829888853873384300443737243229587670317605863427075856829719066740874768132676671162746629352571767661817548721609666404913892013504341078746142248897777527181493200187924013369452904912894553121131117914104587614068776211965526950564476248611022986277500194952900358103146560768359972800847981611729971129561286145669010687768078920716979655526158251366673764816097615550732434057345966333606248485683481426872202229099077575346510591442688826199538018447918118510915583836408992815592476509844119851550500086867335633934419423097250877496152914881242621797749639646343150830260049629685448750923091129566334277174074680079700376566832875144736678644485701380151103395141542971784164455450464060142940953936435619789783362197774298733412053523768682081350101179362750303711070175847385616841106926103577430731109938519416095022152047753921240196677811485678416759670839061024491238725905228765730129119042197897014997053754717401396872532599758105811044749808090902403767976709178484547321575816935816334126886751914357772114302676945383227384454594377992556788735411692433766101855367425417403168055542082907941434365286145923162278557766828015741019604445726546204842557463821394130597144222759876553533919466091306330854250050148420837539871813284051819162537046448242112899336599794795245264768061775712912797050164701770115699874536763426406955593191422814388010490094548861766492289118294164311658601111631881607331828087736984913563217254186457748402439745812620741623624476607508233969180499320277408788470218940968790075222388782483810351490483341945936800617061218592128646579416118200724826446132438381571348532998597425868575472926610150825562374873848918171505444401818771535686728512220744371154470662071094501903248733537974306606701759585832207275436602896065097149216109670257674250538250982245262948436799501094702203299253810679653832962054591454666483753210510397325654901214410070329488767494724285128667994314472669215355224728932912300620060647557016402657488878621905272047891310750308834734747820950450635405847680029957767794737525821942192604713231957423753924232097282651599309748814505475718805773557519681346393090263863200864563902275078204710861548716633798291290952481143604691676350197089216303821457847081364135432925556355141096836091086028
 
    R_exponent = 4096
    # R_inverse = pow(2, -R_exponent, n_squared)
    R_inverse = 81107639473872834862113160384587320505523681558308765561730460247589367636768099250959892926052788716221642552001139066815430567724344860583094243399736604136036937648928790764214416217951032207962309514754178084415447845641019335236679267431433119633245835662314870225975735960080986675999018544597031916700082197447731757331227648495676662127494563984609210881880262024711247896899271401123070539625781199441213299344824755371532711794411004593387207343171154694641025452736023477511533124921413766289410513644881125945554190822796304535623877818134706173653271145599695436068194617130535034171922426463589880815496060798780207388031145331065527728531271242491607203536076325279896483059756225312519985550978966934445095398386444334812097663868943921962473093468666185967862184613865127974750849105162079000335117677294111513038393051091619010878712049841141007755851239397551286050997004771575115216738471204786137390538447029669135710832418064692111189112621983088952873546418413707394233584124680888786573912063405304390478543315596591709252821498200463571641321827454439345060414450593247920183187777785231130217770494721592602618909655619784871745918950283071905258613686252409973737912390260494262666549989272981989941524185
    
    expected_reduction = ((T%n_squared) * R_inverse) % n_squared

    T_dispatcher = dispatch_blocks(T, 256)
    k_dispatcher = dispatch_blocks(k, 128)
    N_dispatcher = dispatch_blocks(n_squared, 128)   
   
   
    # write your test here!
	  # throughout your test, use "assert" statements to test for correct behavior
	  # replace the assertion below with useful statements
    # default parameters are DATA_WIDTH = 8, DATA_CLK_PERIOD = 100
    dut._log.info("Starting...")
    # Start clock with 10ns period (100MHz frequency)
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start()) 
    print("Expected first block output:", expected_reduction % 0xFFFF_FFFF)

    # Test rst_in
    dut.rst_in.value = 1
    dut.valid_in.value = 0
    
    await ClockCycles(dut.clk_in, 10)
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in, 20)
    
    dut.k_constant_block_in.value = next(k_dispatcher)
    dut.modN_constant_block_in.value = next(N_dispatcher)
    
    test_k_dipatcher = dispatch_blocks(k, 128)
    test_N_dispatcher = dispatch_blocks(n_squared, 128) 

    
    # Provide T valid inputs
    for i in range(256):
        dut.valid_in.value = 1
        T_block = next(T_dispatcher)
        dut.T_block_in.value = T_block

        check_for_block_request(dut, k_dispatcher, N_dispatcher) 
        await ClockCycles(dut.clk_in, 1)

        # Test output of MOD
        assert dut.T_modR_block.value == T_block, f"[Cycle {i}] Mod out {dut.T_modR_block.value} not as expected ({T_block})"
        if i < 128:
            assert dut.T_modR_valid.value == 1
        else:
            assert dut.T_modR_valid.value == 0

        # Test input of first multiplier
        if i < 128:
            assert dut.k_constant_block_in.value == next(test_k_dipatcher)

    dut.valid_in.value = 0
    
    ### Expected stuff ###
    expected_Tk_multiplier_result = (T%(2**R_exponent)) * k
    print("First expected Tk block: ", expected_Tk_multiplier_result & 0xFFFF_FFFF)
    test_Tk_multiplier_output = dispatch_blocks(expected_Tk_multiplier_result, 256)
    
    expected_mN_multiplier_result = (expected_Tk_multiplier_result%(2**R_exponent))*n_squared
    test_mN_multiplier_output = dispatch_blocks(expected_mN_multiplier_result, 256)
    
    expected_T_plus_mN_result = expected_mN_multiplier_result + T
    test_T_plus_mN_output = dispatch_blocks(expected_T_plus_mN_result, 256)
    
    ### Continue testing ####
    
    cycles = 256
    while dut.valid_out.value == 0:
        cycles += 1
        
        # Test output of first multiplier (Tk)
        if dut.Tk_product_valid.value == 1:
            expected_Tk_block = next(test_Tk_multiplier_output)
            assert dut.Tk_product_block_value.value == expected_Tk_block, f"[Cycle {cycles}] Output error in Tk multiplier: Got {dut.Tk_product_block_value.value}, expected {expected_Tk_block}"

        # Test output of second multiplier (mN)
        if dut.product_Mn_valid.value == 1:
            expected_mN_block = next(test_mN_multiplier_output)
            assert dut.product_Mn_block.value == expected_mN_block, f"[Cycle {cycles}] Output error in mN multiplier: Got {dut.product_Mn_block.value}, expected {expected_mN_block}"
        
        # Test adder T + mN
        if dut.addition_T_mN_result_valid.value == 1:
            expected_T_plus_mN_block = next(test_T_plus_mN_output)
            assert dut.addition_T_mN_block.value == expected_T_plus_mN_block, f"[Cycle {cycles}] Output error in adder: Got {dut.addition_T_mN_block.value}, expected {expected_T_plus_mN_block}"

        if dut.addition_T_mN_done.value == 1:   # final out
            print("Sum Carry: ", dut.addition_T_mN_block_carry.value)
            expected_carry = expected_T_plus_mN_result >> R_exponent
            assert dut.addition_T_mN_block_carry.value == expected_carry, f"[Cycle {cycles}] Output error in adder CARRY: Got {dut.addition_T_mN_block_carry.value}, expected {expected_carry}"

        
        check_for_block_request(dut, k_dispatcher, N_dispatcher) 
        await ClockCycles(dut.clk_in, 1)
    
    await ClockCycles(dut.clk_in, 100)

    print("Total cycles: ", cycles)
 
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
               
               proj_path / "hdl" / "great_subtractor.sv"] 
    build_test_args = ["-Wall"]#,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="montgomery_reduce",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="montgomery_reduce",
        test_module="test_montgomery_reduce",
        test_args=run_test_args,
        waves=True
    )
 
if __name__ == "__main__":
    test_runner()