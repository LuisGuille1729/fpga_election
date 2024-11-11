import os
import math

def write_mem_data(filename: str, data_width: int, partition_width: int, depth: int, data: list[int]):
    """Create mem file using the mem file format
    Will place every data value in order of the list
    - most relevant bit first
    - each value will always occupy data_width size
    but will be partitioned by partition_width
    - (data_width / partition_width) must be an integer
    which represents the amount of addresses representing the number
    Hence depth must be a multiple of (data_width / partition_width)
    
    
    Once run out of data values, all remaining data will be initialized to 0

    Args:
        filename (str): name of file to stored in mem_files/
        data_width (int): bit size that each value should have
        partition_width (int): bit size stored at each address
        depth (int): total number of values
        data (list[int]): numbers to be placed
    """
    path = os.path.dirname(__file__) + '/mem_files/' + filename

    assert data_width % partition_width == 0, "data_width must be a multiple of partition_width"
    assert depth % (data_width // partition_width) == 0, "depth must be a multiple of (data_width / partition_width)"

    assert len(data)*data_width <= partition_width*depth, "Not enough space for the data"

    n = 1234
    nb = bin(n)
    print(nb)
    print(hex(int(nb, 2)))

    hex_digits_per_partition = math.ceil(partition_width/4)

    cur_depth = 0
    nb = ''
    with open(path, 'w') as f:
        
        for num in data:
            assert num.bit_length() <= data_width, f"data[{cur_depth}] is over {data_width}-bits ({num.bit_length()})"
            
            nb = bin(num)[2:] # convert to binary
            nb = '0'*(data_width-len(nb)) + nb  # insert initial 0s
        
            print(len(nb))

            # write in hex the top partition_width bits
            while len(nb) > 0:
                cur_depth += 1
                f.write(f"{int(nb[0:partition_width], 2): 0{hex_digits_per_partition}x}") 
                if cur_depth != depth:
                    f.write("\n")
                nb = nb[partition_width:]   # remove the top bits
        
        while cur_depth < depth:
            cur_depth += 1
            f.write(f"{0: 0{hex_digits_per_partition}x}")
            if cur_depth != depth:
                f.write("\n")
                
            
        
if __name__ == "__main__":
    # File is created in mem_files/
    
    # data = [305419896, 11111111111111110]
    data = [int("0x1234567890abcdef", 16), int("0xfedcba09876543211234567890abcdef", 16)]
    write_mem_data("adder_demo.mem", data_width=2048, partition_width=32, depth=256, data=data)