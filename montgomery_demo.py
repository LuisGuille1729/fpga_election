import math
import sys
import time

from divider import non_restor_div

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

def calculate_bezout_values(N):
    """
    From a number N (assume it is odd), we find the values satisfying
    kN+1 = RP
    Where R is the next power of 2 larger than N
    
    Out: {N, k, R, P}
    """
    R = 2**(N.bit_length())

    [_, P, k] = extended_euclid_gcd(R, N)
    
    constants = {"N": N, "k": -k, "R": R, "P": P}
    
    print(constants)
    # print(constants["N"]*constants["k"])
    # print(constants["R"]*constants["P"])
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
           
    # print(residue_vals)

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
            # print(T, N, running_product)
        
        T2 = squarer * squarer
        # _, squarer = non_restor_div(T2, N) # equivalent to T2 % N
        squarer = T2 % N
        print(T2, N, squarer)
        
        exp = exp >> 1

    return running_product
    
    
    
if __name__ == "__main__":

    # assert non_restor_div(9, 767) == (0, 9), f"Wrong non_restor result. Got 9 / 767 equal to {non_restor_div(9, 767)}, expected (0, 9)."

    if len(sys.argv) > 1:
        N = int(sys.argv[1])
    else:
        N = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767
    
    constants = calculate_bezout_values(N)

    # ### Montgomery Multiplication ###
    # vals = [5, 6, 7, 10, 3, 5]
    # expected = 1
    # for val in vals:
    #     expected = (expected * val) % N

    # print(run_montgomery_mult(vals, constants))
    # print(expected)
    
    # ### Montgomery Exponentiation ###
    val = 48
    # val = 47474446907289049095635429564137072903698164870863034343472532455285795100993155854631376656387057792449777964780799367513739198538886597232562938222445111514738866185541829579679642609211741238187360952207792826856952396466554705571204399775915282244354822914249603863381046211791595996526971092246526254882834113850978637270579750229477183011088255296991029865554649066991835367171028553345603928570749294841906989436142981451589681445954780830440137236847997517006886394343808081467934804328773848581214616655425095548777895684454475
    exp = 5
    
    result = run_montgomery_exponentiation(val, exp, constants)
    print("Montgomery: ", result)
    
    expected = run_normal_multiplication(val, exp, N)
    print("Normal: ", expected)
    
    expected2 = val**exp % N
    print(expected2)
    assert expected == expected2
    assert result == expected