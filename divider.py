import numpy as np

def extract_outer_bit(num,bit_count):
    return (num - (num % (2**bit_count)))//(2**bit_count) %2

def bit_pos_check(num,bit_count):
    return extract_outer_bit(num,bit_count-1) ==0;

def non_restor_div(Q,M):
    # initialization
    num_bits = int(np.floor(np.log2(Q)) +1)
    A_limit = num_bits+1
    Q_limit = num_bits
    acumulator = 0
    A_clearer =  2**A_limit
    Q_clearer = 2**num_bits



    while (num_bits > 0):
        left_conditional1 = bit_pos_check(acumulator,A_limit)
        # shift left AQ
        Q = Q *2
        acumulator = acumulator *2
        acumulator = acumulator + extract_outer_bit(Q,Q_limit)
        acumulator = acumulator % A_clearer
        Q = Q  %Q_clearer
        # add M or substract M to accumulator based whether we exceed Q or not
        if (left_conditional1):
            acumulator = acumulator - M
        else:
            acumulator = acumulator + M
        left_conditional2 =bit_pos_check(acumulator,A_limit)
        if (left_conditional2):
            Q = Q +1
        else:
            pass
        num_bits = num_bits - 1
            
    left_conditional3 =bit_pos_check(acumulator,A_limit)
    if (left_conditional3):
        acumulator = acumulator % A_clearer
        return (Q,acumulator)
    else:
        acumulator = acumulator + M
        acumulator = acumulator % A_clearer
        return (Q,acumulator)



divisor = 900
for i in range(divisor, divisor*10):
    dividend = i
    Q, R = non_restor_div(dividend,divisor)
    if (Q!= dividend//divisor):
        print(i)
    if (R!= dividend%divisor):
        print(i)



Q,R = non_restor_div(129382984392840,365736)
print(Q)
print(R)