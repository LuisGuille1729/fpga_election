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
    N = 590422124689825055380819807609388189571256327875045759413123457324012204244904348160287525082997271790713457882660955619888946254261043203027771593298628441011612035265723835242026121235268765066944326490013942087806775580532770419185006727693836762421126549971166777350187227849036747874498748898200371278162103260529601535123784241275436339520934294087305771785057763906429748321306960060302877347805301757220204940169408640087558461307977499958542938818185362073916109749225361753465488257725527781630462231753011771059924172480693534542047579157001196799192378909460518139302358557373319671729492711810667118192183711386265644011686234954732739561715352966757275591394362051763747096082775428034331257483730208748244296931348278644467996131508327249311248703598496538092607531165259331139922697302096359403581744626882396938437309021732688016235359847356456980294356847006056239507114391778248012879303412205211396556204524145521662064393273536726990926093148343745926511722322805650194868790817814574744175510423873562280366546710025852968180416945163684882551407895812254630573660655532948916284348570078749620871743294686585436504822696481572626713064081970623249985910047616445949491493081152698162104745221931251546873892289
    R = 2**4096
    print(R%N)
    # data = [305419896, 11111111111111110]
    # data = [int("0x1234567890abcdef", 16), int("0xfedcba09876543211234567890abcdef", 16)]
    data = [R%N]
    write_mem_data("R_modN.mem", data_width=4096, partition_width=32, depth=128, data=data)