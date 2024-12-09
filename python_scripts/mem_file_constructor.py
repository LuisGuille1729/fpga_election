import os
import math

def write_mem_data(filename: str, data_width: int, partition_width: int, depth: int, data: list[int]):
    """Create mem file using the mem file format
    Will place every data value in order of the list
    - least relevant bit first
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
                f.write(f"{int(nb[-partition_width:], 2):0{hex_digits_per_partition}x}") 
                if cur_depth != depth:
                    f.write("\n")
                nb = nb[:-partition_width]   # remove the top bits
        
        while cur_depth < depth:
            cur_depth += 1
            f.write(f"{0:0{hex_digits_per_partition}x}")
            if cur_depth != depth:
                f.write("\n")
                
            
        
if __name__ == "__main__":
    # File is created in mem_files/
    N = 590422124689825055380819807609388189571256327875045759413123457324012204244904348160287525082997271790713457882660955619888946254261043203027771593298628441011612035265723835242026121235268765066944326490013942087806775580532770419185006727693836762421126549971166777350187227849036747874498748898200371278162103260529601535123784241275436339520934294087305771785057763906429748321306960060302877347805301757220204940169408640087558461307977499958542938818185362073916109749225361753465488257725527781630462231753011771059924172480693534542047579157001196799192378909460518139302358557373319671729492711810667118192183711386265644011686234954732739561715352966757275591394362051763747096082775428034331257483730208748244296931348278644467996131508327249311248703598496538092607531165259331139922697302096359403581744626882396938437309021732688016235359847356456980294356847006056239507114391778248012879303412205211396556204524145521662064393273536726990926093148343745926511722322805650194868790817814574744175510423873562280366546710025852968180416945163684882551407895812254630573660655532948916284348570078749620871743294686585436504822696481572626713064081970623249985910047616445949491493081152698162104745221931251546873892289
    R = 2**4096
    n = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767
    k = 143470092535370572884762559577261597060726098095130651285005957313214286020208846248841066413839665875461265127305468068675031009431615257076642373897015244136524563555490527907489468206900169957371718405066201235672090362478853663742336475964379108870711218822319915578568841927832446909576170206724004148662014335256366686051416432871380265066096266104993996707561049975588005673291226873645650089976222132906287395873762164927828399409677542706610136520339776715033573328301612875290174288048957888104513170905651338622165968798603889655834913370256159826940403775407788986108836704031341025569895498152471030201955294429901239594071770739717406269774068252071820981877376647344316707332724263561803448778502843622405588443134412694906949791848247581439427186190448488327675794671096010372437761696016989799470309941546670264823723175030798254161797471206863652908093391507702691498503852245524787840057862796014700934951893477680960594052882015846665426104688827909670722048223991884739539367655706233535869616672961157302847254190896924514009866479293385406880250829014263662616828841246401389608022822438266332289468984960397434107372764152486555063086719771617731206415603770119148562143343177455545346632889001702426541456831
    lambda_val = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959964955464479024933422992909635397164311546361372532118006196725814332208510070121559031989216338031857983916010030668064205891373472234326096586015391335681399251733336672726683199532344809536988586555705039782732792395990414225992198743278061328019762865406265480992968614844386447881974648024301034133270890160
    mu = 8915567752383628781438898187002797896548025900480737799095311841381836545755198503892372879726878495151035115946986868458012154448649583896132194358560329782831378798600255894543884351748301246095759638231762423081258773261447078148315461663411905258069603207263310818435311223030456445831047816378110749327580484779512120318259491191211823394214832953187276053506207701544252431583335833161276475407653180651152186091635887389297141653769732662414014629608293223179202238133723709179125878839638929208525481449388861597926415145013669009524453207751806355956198029749591583141643408193028947053783351959727470281524
    mul_inverse = 75299540386319832354160211189449715021739337572771619406034950168942320910896840776854970153328317531817236329179406815725689583186853726176905598397390492914804344618125333378787729278321822183396226413688586713590845583585245299283933344483047261329067452218606922201317313088493682065927111964296840109381400532732683401088837160650764546687277777040847177422585670354027880681475100346339193036529984948819170330947279644998579025953595192781811896396668196204841894496431652498822227328376699452763141358399571873467329760181720536465116539495136425372850124300208989594033363546950075573838411453104518901916641298228905697185061669962474356751283187733596877822574754600206684623527575365198056857919390629210755372526149688690285459057377006634195232860727511107656767724680749521238380812355199943718493222164182270400520542015300202052832180915193602335560545451968421551161541355504581254594258915106723392088252063735102087361162514814839309376422247892492224101277591803585351248659373063887685892589143245270972989148291111483798381921903845592141897141997014415163682658432361342924395636546114735726870516464138489520449436370149940037433753071794727253607057736971930561852387076048984088400948076
    G_r = ((n+1)*R)%N
    # data = [305419896, 11111111111111110]
    # data = [int("0x1234567890abcdef", 16), int("0xfedcba09876543211234567890abcdef", 16)]
    
    # R mod N
    # data = [R%N]
    # print(hex(data[0])) # expected data written to mem
    # write_mem_data("R_modN.mem", data_width=4096, partition_width=32, depth=128, data=data)
    
    # below for the montgomery caster:
    # R_squared = R*R
    # data = [R_squared%N]
    # write_mem_data("R_squared_modN.mem", data_width=4096, partition_width=32, depth=128, data=data)
    # below for the candidate caster:
    data = [mul_inverse]
    write_mem_data("mul_inverse.mem", data_width=4096, partition_width=32, depth=128, data=data)
    # n = pq
    n = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767