import math
import sys
import time
import random 

from divider import non_restor_div

# Most relevant functions here
#
#   calculate_bezout_constants(N: int) 
#       – obtains k, P, R such that RP = kN + 1 and R > N is the next power of 2
#       - all values will be positive
#   
#  Redc(T: int, constants: dict)
#       - Montgomery REDuCtion
#       - returns TP mod N
#   
#  run_montgomery_exponentiation(val: int, exp: int, constants: dict)
#       - calculates val**exp mod N using montgomery
#   
#   
#   run_montgomery_mult(vals: list[int], constants: dict)
#       - multiplies ints of vals mod N using montgomery
#
#

def timer(func):
    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        duration = time.time() - start
        wrapper.total_time += duration
        print(f"Execution time: {duration}")
        return result

    wrapper.total_time = 0
    return wrapper

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
    R = 2**(N.bit_length())

    [_, P, k] = extended_euclid_gcd(R, N)
    
    k = -k # we instead want RP = kN + 1
    
    if (k < 0):
        k += R
        P += N
    
    constants = {"N": N, "k": k, "R": R, "P": P}   # (with all values positive)
    
    return constants


def Redc(T: int, constants: dict):
    """ Montgomery Reduction.
    Calculates TP where P is the inverse of R mod N
    Assumes that T < RN
    
    Args:
        T: Integer, usually expected to be in Montgomery form
        constants: {N, k, R, P} the constants from the bezout identity
                where   N is the modulo
                        R is the next power of 2 greater than N
                        P,k satisfying RP + kN = 1
    """
    N = constants["N"]
    R_1 = constants["R"]-1
    P = constants["P"]
    k = constants["k"]
    
    m = ((T & R_1) * k ) & R_1
    
    t = (T + m*N) >> (R_1.bit_length())
    
    return t if t < N else t - N

def run_montgomery_mult(vals: list[int], constants: dict):
    """
    Multiply using montgomery all the values of in vals list
    
    Args:
        vals: List of integers to be multiplied with montgomery
        constants: {N, k, R, P} the constants from the bezout identity
            where   N is the modulo
                    R is the next power of 2 greater than N
                    P,k satisfying RP + kN = 1
    """
    N = constants["N"]
    R = constants["R"]
    P = constants["P"]
    k = constants["k"]

    # Change all vals to the montgomery form aR
    residue_vals = []
    memo = {}
    for val in vals:
        if val not in memo:
            _, residue_class = non_restor_div((val*R), N) # Mont Form
            residue_vals.append(residue_class)
            memo[val] = residue_class
        else:
           residue_vals.append(memo[val]) 
           
    # Calculate modular product using Montgomery Reduction
    running_residue = 1*R
    for residue_class in residue_vals:
        T = running_residue * residue_class # T in the form aR * bR
        running_residue = Redc(T, constants)
        
    return Redc(running_residue, constants)

def run_montgomery_mult_precomputed(vals_mont_form: list[int], constants: dict):
    """
    Multiply using montgomery all the values of in vals list
    
    Args:
        vals: List of integers to be multiplied with montgomery
        constants: {N, k, R, P} the constants from the bezout identity
            where   N is the modulo
                    R is the next power of 2 greater than N
                    P,k satisfying RP + kN = 1
    """
    N = constants["N"]
    R = constants["R"]
    P = constants["P"]
    k = constants["k"]

    residue_vals = vals_mont_form

    # Calculate modular product using Montgomery Reduction
    running_residue = 1*R
    for residue_class in residue_vals:
        T = running_residue * residue_class # T in the form aR * bR
        running_residue = Redc(T, constants)
        
    return Redc(running_residue, constants)

        
@timer
def run_montgomery_exponentiation(val: int, exp: int, constants: dict):
    N = constants["N"]
    R = constants["R"]
    P = constants["P"]
    k = constants["k"] 
    
    _, residue_class = non_restor_div((val * R), N) # equivalent to (val * R) % N 
    # residue_class = (val*R) % N
    
    # Nead to do heavy modulo at beginning
    running_residue_product = R   
    residue_squarer = residue_class
    
    
    while exp != 0:
        if (exp & 1):
            T = running_residue_product * residue_squarer
            running_residue_product = Redc(T, constants)
        
        T2 = residue_squarer * residue_squarer
        residue_squarer = Redc(T2, constants)
        
        exp = exp >> 1

    return Redc(running_residue_product, constants)

@timer
def run_montgomery_exponentiation_no_divider(val: int, exp: int, constants: dict, RR_precomputed):
    N = constants["N"]
    R = constants["R"]
    P = constants["P"]
    k = constants["k"] 
    
    
    residue_class = Redc(val * RR_precomputed, constants) # equivalent to val*R*R*R^-1 = val*R
    
    running_residue_product = R   
    residue_squarer = residue_class
    
    while exp != 0:
        if (exp & 1):
            T = running_residue_product * residue_squarer
            running_residue_product = Redc(T, constants)
        
        T2 = residue_squarer * residue_squarer
        residue_squarer = Redc(T2, constants)
        
        exp = exp >> 1

    return Redc(running_residue_product, constants)

@timer
def run_standard_exponentiation(val: int, exp: int, N: int):
    running_product = 1   
    squarer = val
    
    while exp != 0:
        if (exp & 1):
            T = running_product * squarer
            _, running_product = non_restor_div(T, N) # equivalent to T % N
            # running_product = T % N
        
        T2 = squarer * squarer
        _, squarer = non_restor_div(T2, N) # equivalent to T2 % N
        # squarer = T2 % N

        exp = exp >> 1

    return running_product
    
@timer
def run_python_exponentiation(val: int, exp: int, N: int):
    # return val**exp % N
    return pow(val, exp, N)
    
if __name__ == "__main__":

    # (non_restor edge case failing)
    assert non_restor_div(9, 767) == (0, 9), f"Wrong non_restor result. Got 9 / 767 equal to {non_restor_div(9, 767)}, expected (0, 9)."

    if len(sys.argv) > 1:
        N = int(sys.argv[1])
    else:
        # N = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767
        # N = N**2
        N = 57
    
    constants = calculate_bezout_constants(N) 
    # print(constants)

    ### Montgomery Multiplication Precomputed ###
    # vals_mont_form = [1*constants["R"],2*constants["R"]]  # should give 1*2 = 2 
    vals_mont_form = [1, 2] # 1 = mont(R^-1) = mont(49), 2 = mont(2*R^-1) = mont(41)
    result = run_montgomery_mult_precomputed(vals_mont_form, constants)
    print(f"Multiplying (in Mont Form) {vals_mont_form} values mod {N} result : {result}")
    assert result == (math.prod(vals_mont_form) % N) * (constants["P"]**len(vals_mont_form) % N) % N

    ## Montgomery Multiplication ###
    vals = [5, 6, 7, 10, 3, 5]
    # vals = [1,2]
    result = run_montgomery_mult(vals, constants)
    expected = math.prod(vals) % N

    print(f"Multiplying {vals} mod {N}. Result: {result}")
    assert expected == result
    
    ### Montgomery Exponentiation ###
    
    N = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767
    N = N**2
    constants = calculate_bezout_constants(N)
    print(constants)
    
    # val = 48
    # val = 1373975162782546632341976312589651798664932843827249717271219843037546624647515417770993256224607179663782097405155585919186224912368912689987092085024864916625863986004190011294571016320531896670275905622285457944422186450485577817330011023154914210381730826259498368910855424071510567873875262223103536781743356764711
    val = random.randint(2**2000, 2**2048)
    # val = 17494408231072406945641959383517572716256609220143743545686109800938253807137421027191076769856361219009853057109438964090965880194714345910871404702059421073047240693742123820693727628711591608345563709905027454680326713689649156216956752094062262302930285997468486973186103478419749708721165651966962041190556105923989044475570783187580965166641553838761937770637357126252229254051782396435129691082904983188169444768489323357441031007041508901979952213472824900557106322847721591577793751303401203680760962253699292682763609879198170180533887468832814753859729848478231069270608961766203750224943203966595115573832
    
    exp = 2048

    # N = 19
    # constants = calculate_bezout_constants(N)
    # val = 3
    # exp = 10
    
    print(f"\nMontgomery vs Standard Exponentiation: {val.bit_length()}-bit number ^ {exp} (mod {N.bit_length()}-bits number)")
    
    print("\nMontgomery + non_restor_div: ")
    result = run_montgomery_exponentiation(val, exp, constants)

    RR_precomputed = constants["R"]**2 % N
    # print(RR_precomputed)
    print("\nMontgomery (no divider): ")
    result2 = run_montgomery_exponentiation_no_divider(val, exp, constants, RR_precomputed)
    
    # print("\nOriginal Algorithm + non_restor_div: ")
    # expected = run_standard_exponentiation(val, exp, N)
    
    print("\nPython pow(): ")
    expected2 = run_python_exponentiation(val, exp, N) # sanity check

    print("\n")
    # assert expected == expected2
    assert result == expected2, "Wrong results"
    assert result2 == expected2, "Wrong results"

    R = constants["R"]
    P = constants["P"]
    k = constants["k"]
    N = constants["N"]
    print(f"So the idea is that RP = kN + 1, where N is {N.bit_length()}-bits long, R {R.bit_length()}, P {P.bit_length()}, k {k.bit_length()} ")
    assert R*P == k*N + 1
    print("True")
    print("Then, Montgomery reduction allows us to calculate TP (mod N), as long as T < RN")
    # T = random.randint(0, R*N)
    T = 200758871690825436410313088236191628107781057906053210253817912585342046338298103685170352092366337132001123685783853513510135322026690405477252648433351062080582558313069696262403425387732936374539193247351997013421257732282759891664313583050404414398897222374531075493751726887151942583669649104032962647266220258417409777024295549116756954351583908164197993949325841224992182202441729810694966581052060861943726021703584726017714374593111741031803769758911812010720216242765577742312457580844525092150892898605279880268700009091131999101656577412617511054307704173963364710673576354285557639185312742739425647523636183952351261483563899410616902611959141616789725024297721698597187915049326438303609462934960243857368246563578082924533572725658931814558608897887398694106738814727687100061152231632939411666107174130567335581849516670591956383316266156917625265993730882770833790283807142724757957119093713954157539871036318065232021449832830895599242905265868535389526123299050171349741186236790161427715644671139127801830265648216101173206367840977170804868276432739779291538015922245676525337520512691807810204765593050601185396820183480104693118002962697431582108593056602893163758271883016323498492758125067065025416256413400979801581263269488935591616040771639463245636203910069692857928241716020854673679460318668591229430530476516854182553339097746947041107171156492075879249555322160643241599558675930730879686396380129424923460400384183432902985373026820151752659106988471340255109430510151497370443884316087780450354083927783523241061357365477736208046242520929149805093230133757269622385179063314139891842858636983576141181889993513425800255782452267650027885587705746178126482644365691100649653405137696687949431210985399793198456743006894890335037865396890822479952764208721753382106218049981411984280543033473256584584166160279066400902473189573497182292778127033803965311879935719007939752712372363912023191213891591375634436674320448915328509234407044019902185017252420039018531813789770917803491951637781953729030984082340856663104937138170106238411709005122347556045332800719320549477487192563499612564614355064212647241224463685682361784936394356278410008766771032492105963142914426582405461430178551202669778652229505038840109501321824101986317848118314120866655253449061867789573414994778068759100664085477336277946488130758772837589235115936684686498887491481497750182693099165371817228678343176374816113326928096247468637341073632122618181
    N = 590422124689825055380819807609388189571256327875045759413123457324012204244904348160287525082997271790713457882660955619888946254261043203027771593298628441011612035265723835242026121235268765066944326490013942087806775580532770419185006727693836762421126549971166777350187227849036747874498748898200371278162103260529601535123784241275436339520934294087305771785057763906429748321306960060302877347805301757220204940169408640087558461307977499958542938818185362073916109749225361753465488257725527781630462231753011771059924172480693534542047579157001196799192378909460518139302358557373319671729492711810667118192183711386265644011686234954732739561715352966757275591394362051763747096082775428034331257483730208748244296931348278644467996131508327249311248703598496538092607531165259331139922697302096359403581744626882396938437309021732688016235359847356456980294356847006056239507114391778248012879303412205211396556204524145521662064393273536726990926093148343745926511722322805650194868790817814574744175510423873562280366546710025852968180416945163684882551407895812254630573660655532948916284348570078749620871743294686585436504822696481572626713064081970623249985910047616445949491493081152698162104745221931251546873892289
    P = 81107639473872834862113160384587320505523681558308765561730460247589367636768099250959892926052788716221642552001139066815430567724344860583094243399736604136036937648928790764214416217951032207962309514754178084415447845641019335236679267431433119633245835662314870225975735960080986675999018544597031916700082197447731757331227648495676662127494563984609210881880262024711247896899271401123070539625781199441213299344824755371532711794411004593387207343171154694641025452736023477511533124921413766289410513644881125945554190822796304535623877818134706173653271145599695436068194617130535034171922426463589880815496060798780207388031145331065527728531271242491607203536076325279896483059756225312519985550978966934445095398386444334812097663868943921962473093468666185967862184613865127974750849105162079000335117677294111513038393051091619010878712049841141007755851239397551286050997004771575115216738471204786137390538447029669135710832418064692111189112621983088952873546418413707394233584124680888786573912063405304390478543315596591709252821498200463571641321827454439345060414450593247920183187777785231130217770494721592602618909655619784871745918950283071905258613686252409973737912390260494262666549989272981989941524185
    R = 2**4096
    m = ((T%R)*k) % R
    t = (T + m*N)//R
    t = t if (t < N) else t - N
    assert t == (T*P) % N
    print("True")