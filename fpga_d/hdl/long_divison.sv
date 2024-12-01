// Long division algorithm
// 1. Bit-align the left-most “1” of the divisor with the left-most “1” of the dividend
// 2. Set all quotient bits to “0”
// 3. If the dividend ≥ divisor
//      - Set the quotient bit that corresponds to the position of the divisor to “1”
//      - Subtract the divisor from the dividend
// 4. Shift the divisor 1 bit to the right
// 5. If the leading bit of the divisor is at a position ≥ 0, return to step 3
// 6. Otherwise we’re done