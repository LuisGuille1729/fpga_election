import random

def dispatch_blocks(value, num_blocks, infinite=False):
    while True:
        val = value
        for _ in range(num_blocks):
            yield val & (2**32-1)
            val = val >> 32
            # print(f"Looping after {num_blocks}")
            
        if infinite is False:
            break
        
def small_block_adder(block1, block2, carry_in): # must allow carry_out of 2 bits
    return {"block_out": block1 + block2 + carry_in & 0xFFFF_FFFF, "carry_out": block1 + block2 + carry_in >> 32} 



def blocks_multiplier(num_a, num_b):
    
    running_total = [0 for _ in range(128)] 
    running_total_carry = 0
    
    
    a_blocks = dispatch_blocks(num_a, 64)
    A_block_index = 0
    for A in a_blocks:
        
        previous_upper_AB = 0
        A_sum_carry = 0
        
        b_blocks = dispatch_blocks(num_b, 65)   # NOTICE: must add extra loop to finish off adding the sum_carry and last upper_AB
        B_block_index = 0
        for B in b_blocks:
            
            AB_product = A * B    
            lower_AB = AB_product & 0xFFFF_FFFF
            upper_AB = AB_product >> 32

            # Get lower + prev_upper
            corresponding_low_upper_sum = small_block_adder(lower_AB, previous_upper_AB, A_sum_carry)
            A_sum_carry = corresponding_low_upper_sum["carry_out"]
            previous_upper_AB = upper_AB

            # Now, update the running_total
            new_total_block = small_block_adder(corresponding_low_upper_sum["block_out"], running_total[A_block_index+B_block_index], running_total_carry)
            running_total_carry = new_total_block["carry_out"]
            # print(running_total_carry)
            
            running_total[A_block_index+B_block_index] = new_total_block["block_out"]
            
            B_block_index += 1
        A_block_index += 1
        
        # if A_block_index != 64: 
        #     running_total[A_block_index+B_block_index] = small_block_adder(upper_AB, running_total[A_block_index+B_block_index], running_total_carry)
            
    return running_total
            
            
if __name__ == "__main__":

    for _ in range(1):
        # a = random.randint(0, 2**2048 - 1)
        # b = random.randint(0, 2**2048 - 1)
        # a = 12345678
        # b = 987654321
        a = 12345678912345678
        b = 98765432112345678
        # a = 11
        # b = 18
        # a = random.randint(0, 2**2016-1)
        # b = random.randint(0, 2**2016-1)
        a = 13583442868685417509489719863139788201583791797761573239379167330324900393268995232466333843734139773495875912291422000028026016085503560359261204333389186122567947173227872790765445046959454890422099864575470922592478825349918765646705419372190151484345811391269971758222460966987810694866190523465662923558799993736929631209078757164553250200560916874860220923589160415063430387748060889135266003398100676475100997427082962114457974780640513977488967705679539393597874459200308661079742631311475368713288833669658883229217342238184795651527554820299305999813302838324770227016131954895626411012729190382931
        b = 14230934644926130999228815748441974206703694227085962083936498103792459541478035581094044030187958019180573190890201210909101337244739611577071268025127307277001094462103536288748351595783931724298992124413215742840482030483184042873441637787004668765256936597522609640728876955690751174333445985735796733055925350265334624734268259803643866922368224168122751519525595759669818665298315437507978238373673547888079078803705320496075898928249016267524742323945390664297556032629932870393656737838784440917734830613121617758783530005627041866205317371983271705952760596597771496093835896199302115488325455584238
        a = 2**2048-1
        b = 2**2048-1

        # a = 2**2017-1
        # b = 2**2016-1
        
        # a = 2**97-1
        # b = 2**96-1
        
        print(f"Calculating a * b ({a.bit_length()}-bits * {b.bit_length()}-bits)")

        ab = blocks_multiplier(a, b)
        # print(ab)
        
        expected = dispatch_blocks(a*b, 128)
        expected_l = [val for val in expected]
        # print(expected_l)
        
        # for i in range(128):
        #     print((ab[i] - expected_l[i]))
        #     print(bin(ab[i]), bin(expected_l[i]))
        
        for i in range(128):
            assert ab[i] == expected_l[i], f"Wrong number at block {i}: expected {expected_l[i]}, instead got {ab[i]}, running numbers {a} times {b}"



    

































# A = next(a_blocks)
# B = next(b_blocks)
# p = A * B
# lp_cur = p & 0xFFFF_FFFF
# hp_cur = p >> 32
# hp_last = 0
# c = p >> 64

# product = 0
# low_prod = 0
# high_prod = 0
# prev_high_prod = 0

# prod_sum_carry = 0
# accumulated_carry = 0

# B_block_times_all_a = 0
# accumulated = 0

# a_blocks = dispatch_blocks(a, 64)
# A_index = 0
# for A in a_blocks:
#     # print("Update accumulated to ", new_accumulated)
#     accumulated = accumulated + B_block_times_all_a
#     accumulated_blocks = dispatch_blocks(accumulated, 64)   # get B blocks
#     B_block_times_all_a  = 0
#     B_index = 0
#     b_blocks = dispatch_blocks(b, 64)
#     for B in b_blocks:  # Go over all A blocks and multiply with the current B
#         product = A * B                     # Calculate product of blocks
#         low_prod = product & 0xFFFF_FFFF    # Must divide in bottom block
#         high_prod = product >> 32           # and top block (note there's will never be a carry)
        
#         block_prod_sum = adder(low_prod, prev_high_prod, prod_sum_carry) # Now add low prod with the previous high product
        
#         prod_sum_carry = block_prod_sum["carry_out"] # there might be carry
#         prev_high_prod = high_prod # update pre_high_prod
        
#         # Now combine 
#         new_accumulated_block = adder(block_prod_sum["block_out"], next(accumulated_blocks), accumulated_carry+block_prod_sum["carry_out"])
        
#         B_block_times_all_a = B_block_times_all_a | (new_accumulated_block["block_out"] << (32*(B_index+A_index)))
#         # print("New:", new_accumulated)
#         B_index += 1
#     A_index += 1

# accumulated = accumulated + B_block_times_all_a

# print(accumulated)
# assert accumulated == a*b, f"Obtained {hex(accumulated)}, expected {hex(a*b)}"