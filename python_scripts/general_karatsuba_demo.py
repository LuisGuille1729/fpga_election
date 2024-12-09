from random import randint
# source: https://eprint.iacr.org/2006/224.pdf

def dispatch_blocks(value, num_blocks, infinite=False, block_size=32):
    while True:
        val = value
        for _ in range(num_blocks):
            yield val & (2**block_size-1)
            val = val >> block_size
            # print(f"Looping after {num_blocks}")
            
        if infinite is False:
            break
        
def block_list(value, num_blocks, block_size=32):
    dispatcher = dispatch_blocks(value, num_blocks, False, block_size)
    return [num for num in dispatcher]
    

def karatsuba64(A, B):
    A1 = A & 0xFFFF_FFFF
    A2 = A >> 32
    B1 = B & 0xFFFF_FFFF
    B2 = B >> 32
    
    z0 = A1*B1
    z2 = A2*B2
    z1_intermediate = (A1+A2)*(B1+B2)
    z1 = z1_intermediate - z0 - z2
    
    # assert z1 == (A1*B2 + A2*B1)
    return (z2 << 64) + (z1 << 32) + z0


def binomial_multiplier_128(A, B):
    A = block_list(A, 4)
    B = block_list(B, 4)
    
    R0 = A[0]*B[0]
    R1 = A[0]*B[1] + A[1]*B[0]
    R2 = A[0]*B[2] + A[1]*B[1] + A[2]*B[0]
    R3 = A[0]*B[3] + A[1]*B[2] + A[2]*B[1] + A[3]*B[0]
    R4 = A[1]*B[3] + A[2]*B[2] + A[3]*B[1]
    R5 = A[2]*B[3] + A[3]*B[2]
    R6 = A[3]*B[3]

    return R0 + (R1 << 32) + (R2 << 64) + (R3 << 96) + (R4 << 128) + (R5 << 160) + (R6 << 192)

def generalized_karatsuba(A, B, n=4):
    A = block_list(A, n)
    B = block_list(B, n) 
    
    dot_product = [A[i] * B[i] for i in range(n)]
    # print(dot_product)

    sum_product = [[(A[s]+A[t])*(B[s]+B[t]) for s in range(t) if t < n and s < n] for t in range(n)]
    # print(sum_product)
    
    running_total = 0
    total_muls = len(dot_product)
    for i in range(2*n-1): # 0, 1, 2, 3, 4, 5, 6
        if i == 0 or i == 2*n-2:
            running_total += dot_product[i//2] << (32*i)
            # print(i, hex(dot_product[i//2] << (32*i)))
        elif i % 2 == 1:
            for s in range(0, (i//2)+1):
                # print(i, i-s, s)
                running_total += (sum_product[i-s][s] << (32*i)) if i-s < n and s < n else 0
                running_total -= ((dot_product[s] + dot_product[i-s]) << (32*i)) if i-s < n and s < n else 0
                total_muls += 1  if i-s < n and s < n else 0 # for the sum_product
        else:
            for s in range(0, i//2):
                # print(i, i-s, s)
                running_total += (sum_product[i-s][s] << (32*i)) if i-s < n and s < n else 0
                running_total -= ((dot_product[s] + dot_product[i-s]) << (32*i)) if i-s < n and s < n else 0
                total_muls += 1 if i-s < n and s < n else 0 # for the sum_product
                
            running_total += dot_product[i//2] << (32*i)
    
    print(f"Total multiplications: {total_muls}")
    return running_total
            
                
            


if __name__ == '__main__':
    
    for i in range(100):
        A = randint(0, 2**64-1)
        B = randint(0, 2**64-1)
        assert karatsuba64(A,B) == A*B, f"[{i}] {A}*{B} equals {A*B} not {karatsuba64(A,B)}"

    for i in range(100):
        A = randint(0, 2**128-1)
        B = randint(0, 2**128-1)
        assert binomial_multiplier_128(A,B) == A*B, f"[{i}] {A}*{B} equals {A*B} not {binomial_multiplier_128(A,B)}"
        
    # A = randint(0, 2**128-1)
    # B = randint(0, 2**128-1) 
    # r = generalized_karatsuba(A, B, 4)
    # # print(hex(r))
    # # print(hex(A*B))
    # # print(hex(r - A*B))
    # assert r == A*B 

    # A = randint(0, 2**96-1)
    # B = randint(0, 2**96-1) 
    # r = generalized_karatsuba(A, B, 4)
    # # print(hex(r))
    # # print(hex(A*B))
    # # print(hex(r - A*B))
    # assert r == A*B

    blocks_amount = 128
    A = randint(0, 2**(32*blocks_amount)-1)
    B = randint(0, 2**(32*blocks_amount)-1) 
    r = generalized_karatsuba(A, B, blocks_amount)
    # print(hex(r))
    # print(hex(A*B))
    # print(hex(r - A*B))
    assert r == A*B