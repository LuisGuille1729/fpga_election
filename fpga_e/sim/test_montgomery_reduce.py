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
def extended_euclid_gcd(a: int, b: int):
    """
    https://www.rookieslab.com/posts/extended-euclid-algorithm-to-find-gcd-bezouts-coefficients-python-cpp-code
    Returns a list `result` of size 3 where:
    Referring to the equation ax + by = gcd(a, b)
        result[0] is gcd(a, b)
        result[1] is x
        result[2] is y 
    """
    s = 0; old_s = 1    # start 
    t = 1; old_t = 0
    r = b; old_r = a    # quotient a//b

    while r != 0:
        quotient = old_r//r # In Python, // operator performs integer or floored division
        # This is a pythonic way to swap numbers
        # See the same part in C++ implementation below to know more
        old_r, r = r, old_r - quotient*r        # gcd(a,b)
        old_s, s = s, old_s - quotient*s        # x
        old_t, t = t, old_t - quotient*t        # y
    return [old_r, old_s, old_t]    # [gcd(a,b), x, y]
def calculate_bezout_constants(N: int):
    """
    From a number N (assume it is odd), we find the values satisfying
    kN+1 = RP
    Where R is the next power of 2 larger than N
    
    Out: {N, k, R, P}
    """
    # R = 2**(N.bit_length())
    R = 2**4096

    [_, P, k] = extended_euclid_gcd(R, N)
    
    k = -k # we instead want RP = kN + 1
    
    if (k < 0):
        k += R
        P += N
    
    constants = {"N": N, "k": k, "R": R, "P": P}   # (with all values positive)
    
    return constants
 
def dispatch_blocks(value, num_blocks):
    while True:
        val = value
        for _ in range(num_blocks):
            yield val & 0xFFFF_FFFF
            val = val >> 32
        # print(f"Looping after {num_blocks}")

def check_for_block_request(dut, k_dispatcher, N_dispatcher):
    if (dut.consumed_k_out.value):
        dut.k_constant_block_in.value = next(k_dispatcher)
    if (dut.consumed_N_out.value):
        dut.modN_constant_block_in.value = next(N_dispatcher)
    # return (next(k_dispatcher), next(N_dispatcher))

async def test_reduction_outputs(dut, T, N, P, global_k_dispatcher, global_N_dispatcher):
    """
    Provides valid inputs and asserts that the outputs are exactly as expected.
    """
    expected_reduction = ((T%N)*P)%N
    expected_output_dispatcher = dispatch_blocks(expected_reduction, 128)

    T_dispatcher = dispatch_blocks(T, 256)

    # Provide T valid inputs
    for i in range(256):
        dut.valid_in.value = 1
        T_block = next(T_dispatcher)
        dut.T_block_in.value = T_block

        check_for_block_request(dut, global_k_dispatcher, global_N_dispatcher) 
        await ClockCycles(dut.clk_in, 1)
    
    dut.valid_in.value = 0

    # Wait until start outputting result
    calculating_cycles = 0
    while dut.valid_out.value == 0:
        calculating_cycles += 1
        check_for_block_request(dut, global_k_dispatcher, global_N_dispatcher) 
        await ClockCycles(dut.clk_in, 1)
    
    # Get result
    output_cycles = 0
    while dut.valid_out.value == 1:
        output_cycles += 1
        expected_block = next(expected_output_dispatcher)
        # print(output_cycles, expected_block)
        assert dut.data_block_out.value == expected_block, f"[out cycle {output_cycles}] WRONG Output block: {int(dut.data_block_out.value)} instead of {expected_block}"
        
        check_for_block_request(dut, global_k_dispatcher, global_N_dispatcher) 
        await ClockCycles(dut.clk_in, 1)
    
    assert output_cycles == 128, f"Obtained wrong number ({output_cycles}) of output blocks"
    
    return 256 + calculating_cycles + output_cycles
    


@cocotb.test()
async def testing(dut):   
   
   
    # write your test here!
	  # throughout your test, use "assert" statements to test for correct behavior
	  # replace the assertion below with useful statements
    # default parameters are DATA_WIDTH = 8, DATA_CLK_PERIOD = 100
    dut._log.info("Starting...")
    # Start clock with 10ns period (100MHz frequency)
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start()) 
    # print("Expected first block output:", expected_reduction & 0xFFFF_FFFF)
    # print("Expected second block output:", (expected_reduction>>32) & 0xFFFF_FFFF)
    # print("Expected third block output:", (expected_reduction>>64) & 0xFFFF_FFFF)

    # Test rst_in
    dut.rst_in.value = 1
    dut.valid_in.value = 0
    
    await ClockCycles(dut.clk_in, 10)
    dut.rst_in.value = 0
    
    await ClockCycles(dut.clk_in, 20)
    
    n_squared = 590422124689825055380819807609388189571256327875045759413123457324012204244904348160287525082997271790713457882660955619888946254261043203027771593298628441011612035265723835242026121235268765066944326490013942087806775580532770419185006727693836762421126549971166777350187227849036747874498748898200371278162103260529601535123784241275436339520934294087305771785057763906429748321306960060302877347805301757220204940169408640087558461307977499958542938818185362073916109749225361753465488257725527781630462231753011771059924172480693534542047579157001196799192378909460518139302358557373319671729492711810667118192183711386265644011686234954732739561715352966757275591394362051763747096082775428034331257483730208748244296931348278644467996131508327249311248703598496538092607531165259331139922697302096359403581744626882396938437309021732688016235359847356456980294356847006056239507114391778248012879303412205211396556204524145521662064393273536726990926093148343745926511722322805650194868790817814574744175510423873562280366546710025852968180416945163684882551407895812254630573660655532948916284348570078749620871743294686585436504822696481572626713064081970623249985910047616445949491493081152698162104745221931251546873892289
    # N_stress = random.randint(2**4094, 2**4096-1)
    # N_stress = random.randint(2**4095, 2**4096-1)
    # N_stress = N_stress|1 # make sure its odd
    N_stress = n_squared
    print("N bits: ", N_stress.bit_length())
    
    constants = calculate_bezout_constants(N_stress)
    P_stress = constants["P"]
    k_stress = constants["k"]
    # Stress test, focusing on the outputs
    global_k_dispatcher = dispatch_blocks(k_stress, 128)
    global_N_dispatcher = dispatch_blocks(N_stress, 128)   
    dut.k_constant_block_in.value = next(global_k_dispatcher)
    dut.modN_constant_block_in.value = next(global_N_dispatcher)
    
    test_edges = True
    test_our_N = False
    test_arbitrary_N = False
    
    if test_edges:
        print("Test edge cases with our n_squared")
        
        T = N_stress
        cycles = await test_reduction_outputs(dut, T, N_stress, P_stress, global_k_dispatcher, global_N_dispatcher)
        print(f"Test (T=N) successful in {cycles} cycles.") 
        
        T = 0
        cycles = await test_reduction_outputs(dut, T, N_stress, P_stress, global_k_dispatcher, global_N_dispatcher)
        print(f"Test (T=0) successful in {cycles} cycles.") 
        
        T = N_stress<<4096
        cycles = await test_reduction_outputs(dut, T, N_stress, P_stress, global_k_dispatcher, global_N_dispatcher)
        print(f"Test (T=RN) successful in {cycles} cycles.") 

        T = 1
        cycles = await test_reduction_outputs(dut, T, N_stress, P_stress, global_k_dispatcher, global_N_dispatcher)
        print(f"Test (T=1) successful in {cycles} cycles.") 
    
    if test_our_N:
        print("Stress test with our n_squared and random T")
        for i in range(20):
            T = random.randint(0, N_stress<<4096)
            cycles = await test_reduction_outputs(dut, T, N_stress, P_stress, global_k_dispatcher, global_N_dispatcher)
            print(f"Test #{i} successful in {cycles} cycles. (T {T.bit_length()}-bits)")
        for i in range(20, 40):
            T = random.randint(0, N_stress)
            cycles = await test_reduction_outputs(dut, T, N_stress, P_stress, global_k_dispatcher, global_N_dispatcher)
            print(f"Test #{i} successful in {cycles} cycles. (T {T.bit_length()}-bits)")
        for i in range(40, 60):
            T = random.randint(0, N_stress/2)
            cycles = await test_reduction_outputs(dut, T, N_stress, P_stress, global_k_dispatcher, global_N_dispatcher)
            print(f"Test #{i} successful in {cycles} cycles. (T {T.bit_length()}-bits)")
        for i in range(60, 80):
            T = random.randint(0, N_stress>>100)
            cycles = await test_reduction_outputs(dut, T, N_stress, P_stress, global_k_dispatcher, global_N_dispatcher)
            print(f"Test #{i} successful in {cycles} cycles. (T {T.bit_length()}-bits)")  
        for i in range(80, 100):
            T = random.randint(0, 123456789)
            cycles = await test_reduction_outputs(dut, T, N_stress, P_stress, global_k_dispatcher, global_N_dispatcher)
            print(f"Test #{i} successful in {cycles} cycles. (T {T.bit_length()}-bits)")  
    
    
    if test_arbitrary_N:
        print("Test for arbitrary N")
        
        for i in range(10):
            N_stress = random.randint(2**3000, 2**4096-1)
            N_stress = N_stress|1 # make sure its odd, to guarantee gcd(N,R)=1
            print(f"[{i}] New N ({N_stress.bit_length()}-bits).")
            constants = calculate_bezout_constants(N_stress)
            P_stress = constants["P"]
            k_stress = constants["k"]
            assert constants["R"]*P_stress == k_stress*N_stress + 1
            global_k_dispatcher = dispatch_blocks(k_stress, 128)
            global_N_dispatcher = dispatch_blocks(N_stress, 128)   
            dut.k_constant_block_in.value = next(global_k_dispatcher)
            dut.modN_constant_block_in.value = next(global_N_dispatcher)
            
            for j in range(3):
                T = random.randint(0, 2*N_stress)
                cycles = await test_reduction_outputs(dut, T, N_stress, P_stress, global_k_dispatcher, global_N_dispatcher)
                print(f"Test #{j} successful in {cycles} cycles. (T {T.bit_length()}-bits)")  
    
    
    # Below is a singular test useful for debugging individual signals
    
    k = 143470092535370572884762559577261597060726098095130651285005957313214286020208846248841066413839665875461265127305468068675031009431615257076642373897015244136524563555490527907489468206900169957371718405066201235672090362478853663742336475964379108870711218822319915578568841927832446909576170206724004148662014335256366686051416432871380265066096266104993996707561049975588005673291226873645650089976222132906287395873762164927828399409677542706610136520339776715033573328301612875290174288048957888104513170905651338622165968798603889655834913370256159826940403775407788986108836704031341025569895498152471030201955294429901239594071770739717406269774068252071820981877376647344316707332724263561803448778502843622405588443134412694906949791848247581439427186190448488327675794671096010372437761696016989799470309941546670264823723175030798254161797471206863652908093391507702691498503852245524787840057862796014700934951893477680960594052882015846665426104688827909670722048223991884739539367655706233535869616672961157302847254190896924514009866479293385406880250829014263662616828841246401389608022822438266332289468984960397434107372764152486555063086719771617731206415603770119148562143343177455545346632889001702426541456831
    n_squared = 590422124689825055380819807609388189571256327875045759413123457324012204244904348160287525082997271790713457882660955619888946254261043203027771593298628441011612035265723835242026121235268765066944326490013942087806775580532770419185006727693836762421126549971166777350187227849036747874498748898200371278162103260529601535123784241275436339520934294087305771785057763906429748321306960060302877347805301757220204940169408640087558461307977499958542938818185362073916109749225361753465488257725527781630462231753011771059924172480693534542047579157001196799192378909460518139302358557373319671729492711810667118192183711386265644011686234954732739561715352966757275591394362051763747096082775428034331257483730208748244296931348278644467996131508327249311248703598496538092607531165259331139922697302096359403581744626882396938437309021732688016235359847356456980294356847006056239507114391778248012879303412205211396556204524145521662064393273536726990926093148343745926511722322805650194868790817814574744175510423873562280366546710025852968180416945163684882551407895812254630573660655532948916284348570078749620871743294686585436504822696481572626713064081970623249985910047616445949491493081152698162104745221931251546873892289

    # T 8192-bits long
    # T = random.randint(0, 2**8192-1)
    T = 668046964085213323677521973090209666948265322575032540699613055124432667085172110660147195335909942987381575932157651701154744675200694478842057168218319856257092368160970530081040347415486829888853873384300443737243229587670317605863427075856829719066740874768132676671162746629352571767661817548721609666404913892013504341078746142248897777527181493200187924013369452904912894553121131117914104587614068776211965526950564476248611022986277500194952900358103146560768359972800847981611729971129561286145669010687768078920716979655526158251366673764816097615550732434057345966333606248485683481426872202229099077575346510591442688826199538018447918118510915583836408992815592476509844119851550500086867335633934419423097250877496152914881242621797749639646343150830260049629685448750923091129566334277174074680079700376566832875144736678644485701380151103395141542971784164455450464060142940953936435619789783362197774298733412053523768682081350101179362750303711070175847385616841106926103577430731109938519416095022152047753921240196677811485678416759670839061024491238725905228765730129119042197897014997053754717401396872532599758105811044749808090902403767976709178484547321575816935816334126886751914357772114302676945383227384454594377992556788735411692433766101855367425417403168055542082907941434365286145923162278557766828015741019604445726546204842557463821394130597144222759876553533919466091306330854250050148420837539871813284051819162537046448242112899336599794795245264768061775712912797050164701770115699874536763426406955593191422814388010490094548861766492289118294164311658601111631881607331828087736984913563217254186457748402439745812620741623624476607508233969180499320277408788470218940968790075222388782483810351490483341945936800617061218592128646579416118200724826446132438381571348532998597425868575472926610150825562374873848918171505444401818771535686728512220744371154470662071094501903248733537974306606701759585832207275436602896065097149216109670257674250538250982245262948436799501094702203299253810679653832962054591454666483753210510397325654901214410070329488767494724285128667994314472669215355224728932912300620060647557016402657488878621905272047891310750308834734747820950450635405847680029957767794737525821942192604713231957423753924232097282651599309748814505475718805773557519681346393090263863200864563902275078204710861548716633798291290952481143604691676350197089216303821457847081364135432925556355141096836091086028
    # T = 200758871690825436410313088236191628107781057906053210253817912585342046338298103685170352092366337132001123685783853513510135322026690405477252648433351062080582558313069696262403425387732936374539193247351997013421257732282759891664313583050404414398897222374531075493751726887151942583669649104032962647266220258417409777024295549116756954351583908164197993949325841224992182202441729810694966581052060861943726021703584726017714374593111741031803769758911812010720216242765577742312457580844525092150892898605279880268700009091131999101656577412617511054307704173963364710673576354285557639185312742739425647523636183952351261483563899410616902611959141616789725024297721698597187915049326438303609462934960243857368246563578082924533572725658931814558608897887398694106738814727687100061152231632939411666107174130567335581849516670591956383316266156917625265993730882770833790283807142724757957119093713954157539871036318065232021449832830895599242905265868535389526123299050171349741186236790161427715644671139127801830265648216101173206367840977170804868276432739779291538015922245676525337520512691807810204765593050601185396820183480104693118002962697431582108593056602893163758271883016323498492758125067065025416256413400979801581263269488935591616040771639463245636203910069692857928241716020854673679460318668591229430530476516854182553339097746947041107171156492075879249555322160643241599558675930730879686396380129424923460400384183432902985373026820151752659106988471340255109430510151497370443884316087780450354083927783523241061357365477736208046242520929149805093230133757269622385179063314139891842858636983576141181889993513425800255782452267650027885587705746178126482644365691100649653405137696687949431210985399793198456743006894890335037865396890822479952764208721753382106218049981411984280543033473256584584166160279066400902473189573497182292778127033803965311879935719007939752712372363912023191213891591375634436674320448915328509234407044019902185017252420039018531813789770917803491951637781953729030984082340856663104937138170106238411709005122347556045332800719320549477487192563499612564614355064212647241224463685682361784936394356278410008766771032492105963142914426582405461430178551202669778652229505038840109501321824101986317848118314120866655253449061867789573414994778068759100664085477336277946488130758772837589235115936684686498887491481497750182693099165371817228678343176374816113326928096247468637341073632122618181
    # print(T)
 
    R_exponent = 4096
    # R_inverse = pow(2, -R_exponent, n_squared)
    R_inverse = 81107639473872834862113160384587320505523681558308765561730460247589367636768099250959892926052788716221642552001139066815430567724344860583094243399736604136036937648928790764214416217951032207962309514754178084415447845641019335236679267431433119633245835662314870225975735960080986675999018544597031916700082197447731757331227648495676662127494563984609210881880262024711247896899271401123070539625781199441213299344824755371532711794411004593387207343171154694641025452736023477511533124921413766289410513644881125945554190822796304535623877818134706173653271145599695436068194617130535034171922426463589880815496060798780207388031145331065527728531271242491607203536076325279896483059756225312519985550978966934445095398386444334812097663868943921962473093468666185967862184613865127974750849105162079000335117677294111513038393051091619010878712049841141007755851239397551286050997004771575115216738471204786137390538447029669135710832418064692111189112621983088952873546418413707394233584124680888786573912063405304390478543315596591709252821498200463571641321827454439345060414450593247920183187777785231130217770494721592602618909655619784871745918950283071905258613686252409973737912390260494262666549989272981989941524185
    
    expected_reduction = (T * R_inverse) % n_squared

    T_dispatcher = dispatch_blocks(T, 256)
    k_dispatcher = dispatch_blocks(k, 128)
    N_dispatcher = dispatch_blocks(n_squared, 128)
    
    
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
    # print("First expected Tk block: ", expected_Tk_multiplier_result & 0xFFFF_FFFF)
    test_Tk_multiplier_output = dispatch_blocks(expected_Tk_multiplier_result, 256)
    
    expected_mN_multiplier_result = (expected_Tk_multiplier_result%(2**R_exponent))*n_squared
    test_mN_multiplier_output = dispatch_blocks(expected_mN_multiplier_result, 256)
    
    expected_T_plus_mN_result = expected_mN_multiplier_result + T
    test_T_plus_mN_output = dispatch_blocks(expected_T_plus_mN_result, 256)
    
    expected_t_result = expected_T_plus_mN_result >> R_exponent
    test_t_output = dispatch_blocks(expected_t_result, 128)
    test_t_output2 = dispatch_blocks(expected_t_result, 128)

    expected_adjusted_t_result = expected_t_result if expected_t_result < n_squared else expected_t_result - n_squared
    assert expected_reduction == expected_adjusted_t_result, "Sanity check"
    
    running_t = 0
    running_N = 0
    comparison_cycle = 0
    comparison_finished_cycles = 0
    ### Continue testing ####
    
    ## TEST OUTPUTS OF MODULES INDIVUALLY
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
            # print("Sum Carry: ", dut.addition_T_mN_block_carry.value)
            expected_carry = expected_T_plus_mN_result >> 8192
            assert dut.addition_T_mN_block_carry.value == expected_carry, f"[Cycle {cycles}] Output error in adder CARRY: Got {dut.addition_T_mN_block_carry.value}, expected {expected_carry}"

        # Test shifter
        if dut.rshift_T_mN_byR_valid.value == 1:
            expected_t_block = next(test_t_output)
            assert dut.rshift_T_mN_byR_block.value == expected_t_block, f"[Cycle {cycles}] Output error in shift output: Got {dut.rshift_T_mN_byR_block.value}, expected {expected_t_block}"

        # Test comparison
        if dut.comparison_result.value != 0:
            # Comparing t and N
            running_t += next(test_t_output2) << (32*comparison_cycle)
            running_N += next(test_N_dispatcher) << (32*comparison_cycle)
            comparison_cycle += 1
            
            # print(cycles)
            # print("Expected Inputs: ", hex(running_t), hex(running_N))
            # print("Actual Inputs: ", hex(dut.t_result_block_value.value), hex(dut.modN_constant_block_in.value))
            if (running_t < running_N):
                assert dut.comparison_result.value == 1, f"[Cycle {cycles}] Comparison error. Expected t < N, got {dut.comparison_result.value}"
            elif (running_t == running_N):
                assert dut.comparison_result.value == 3, f"[Cycle {cycles}] Comparison error. Expected t == N, got {dut.comparison_result.value}"
            else:
                assert dut.comparison_result.value == 2, f"[Cycle {cycles}] Comparison error. Expected t > N, got {dut.comparison_result.value}"
        
        # Test final is_t_less_than_N
        if comparison_finished_cycles != 0:
            comparison_finished_cycles += 1
        if dut.comparison_done.value == 1:
            comparison_finished_cycles += 1
            # print("Comparison result: ", dut.comparison_result.value)
        

        if comparison_finished_cycles == 2:
            assert expected_t_result == (expected_carry << 4096) + running_t # sanity checking
            expected_comparison = (expected_t_result < running_N)
            # print("Expected comparison:", expected_comparison, "Got comparison:", dut.is_t_less_than_N.value)
            assert dut.is_t_less_than_N.value == expected_comparison
        
        check_for_block_request(dut, k_dispatcher, N_dispatcher) 
        await ClockCycles(dut.clk_in, 1)
    
    await ClockCycles(dut.clk_in, 200)

    print("Total cycles one reduction: ", cycles)
    
    # print("Expected output:")
    # t_output = dispatch_blocks(expected_adjusted_t_result, 128)
    # for _ in range(128):
    #     print(next(t_output))
 
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