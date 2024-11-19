import numpy as np

def fft_multiply_large_base(num1, num2, base=2):
    # Split num1 and num2 into chunks of 32-bit integers
    def split_to_base(num, base):
        chunks = []
        while num > 0:
            chunks.append(num % base)
            num //= base
        return np.array(chunks, dtype=int)
    
    A = split_to_base(num1, base)
    B = split_to_base(num2, base)
    
    # Find appropriate FFT size (next power of two for speed)
    size = 2 ** int(np.ceil(np.log2(len(A) + len(B))))

    print(" size 1:", len(A))

    print(" size 2:", len(B))

    print(" size 3:", size)
    
    # Perform FFT
    fft_A = np.fft.fft(A, size)
    print(" size 4:", len(fft_A))
    fft_B = np.fft.fft(B, size)

    # print(fft_A)
    print(len(fft_A))
    
    # Pointwise multiplication in the frequency domain
    fft_result = fft_A * fft_B

    # for i in range(len(fft_result)):
    #     print(fft_A[i])

    
    # Inverse FFT to get polynomial coefficients in time domain
    result_coeffs = np.fft.ifft(fft_result).real.round().astype(int)

    # print(result_coeffs)
    # print(np.fft.ifft(fft_result))
    
    # Handle carries with the new base
    carry = 0
    for i in range(len(result_coeffs)):
        result_coeffs[i] += carry
        carry = result_coeffs[i] // base
        result_coeffs[i] %= base
    
    # Convert coefficients back to integer
    result = 0
    for coeff in reversed(result_coeffs):
        result = result * base + coeff
    return result

# Example usage
num1 = 12345678901234567890
num2 = 98765432109876543210
print(fft_multiply_large_base(num1, num2,2))