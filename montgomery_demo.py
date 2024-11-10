import math
import sys
import time

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

def extended_euclid_gcd(a, b):
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

def calculate_bezout_constants(N):
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


def Redc(T, constants):
    """ Montgomery Reduction.
    Calculates TP where P is the inverse of R mod N
    
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

def run_montgomery_mult(vals, constants):
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
            residue_class = (val*R) % N
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

def run_montgomery_mult_precomputed(vals_mont_form, constants):
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
def run_montgomery_exponentiation(val, exp, constants):
    N = constants["N"]
    R = constants["R"]
    P = constants["P"]
    k = constants["k"] 
    
    # _, residue_class = non_restor_div((val * R), N) # equivalent to (val * R) % N 
    residue_class = (val * R) % N
    
    # Nead to do heavy modulo at beginning
    running_residue_product = R   
    residue_squarer = residue_class
    
    # x[n]
    
    while exp != 0:
        if (exp & 1):
            T = running_residue_product * residue_squarer
            running_residue_product = Redc(T, constants)
        
        T2 = residue_squarer * residue_squarer
        residue_squarer = Redc(T2, constants)
        
        exp = exp >> 1

    return Redc(running_residue_product, constants)
        
@timer
def run_normal_multiplication(val, exp, N):
    running_product = 1   
    squarer = val
    
    while exp != 0:
        if (exp & 1):
            T = running_product * squarer
            # _, running_product = non_restor_div(T, N) # equivalent to T % N
            running_product = T % N
        
        T2 = squarer * squarer
        # _, squarer = non_restor_div(T2, N) # equivalent to T2 % N
        squarer = T2 % N
        
        exp = exp >> 1

    return running_product
    
    
    
if __name__ == "__main__":

    # (non_restor edge case failing)
    # assert non_restor_div(9, 767) == (0, 9), f"Wrong non_restor result. Got 9 / 767 equal to {non_restor_div(9, 767)}, expected (0, 9)."

    if len(sys.argv) > 1:
        N = int(sys.argv[1])
    else:
        # N = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767
        # N = N**2
        N = 57
    
    constants = calculate_bezout_constants(N) 
    print(constants)

    ### Montgomery Multiplication Precomputed ###
    # vals_mont_form = [1*constants["R"],2*constants["R"]]  # should give 1*2 = 2 
    vals_mont_form = [1, 2] # 1 = mont(R^-1) = mont(49), 2 = mont(2*R^-1) = mont(41)
    result = run_montgomery_mult_precomputed(vals_mont_form, constants)
    print(f"Mult mod {N} (In Mont Form {vals_mont_form}) result : {result}")
    assert result == (math.prod(vals_mont_form) % N) * (constants["P"]**len(vals_mont_form) % N) % N

    ## Montgomery Multiplication ###
    vals = [5, 6, 7, 10, 3, 5]
    # vals = [1,2]
    result = run_montgomery_mult(vals, constants)
    expected = math.prod(vals) % N

    print(f"Mult mod {N} ({vals}) result: {result}")
    assert expected == result
    
    ### Montgomery Exponentiation ###
    val = 48
    val = 137397516278254663234197631258965179872686664932843827249717271219843037546624647515417770993256224607179663782097405155585919186224912368912689987092085024864916625863986004190011294571016320531896670275905622285457944422186450485577817330011023154914210381730826259498368910855424071510567873875262223103536781743356764711
    exp = 10000
    
    print("Montgomery vs Normal Exponentiation:")
    result = run_montgomery_exponentiation(val, exp, constants)
    # print("Montgomery: ", result)
    
    expected = run_normal_multiplication(val, exp, N)
    # print("Normal: ", expected)
    
    # expected2 = val**exp % N # sanity check, very slow
    # assert expected == expected2
    assert result == expected