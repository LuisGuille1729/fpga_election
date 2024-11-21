from phe import paillier
import random
import math
import sys
# if you haven't: pip install phe (only used for key generation) 
# https://python-paillier.readthedocs.io/en/stable/usage.html
# https://python-paillier.readthedocs.io/en/stable/phe.html#module-phe.paillier

class Keys:
    def __init__(self, public, private):
        self.public: Public_Key = public
        self.private: Private_Key = private
            
class Public_Key:
    def __init__(self, n, g):
        self.n = n
        self.g = g
        self.n_square = n**2

class Private_Key:
    def __init__(self, lambd, mu):
        self.lambd = lambd
        self.mu = mu


def generate_keys(generate_new=False, verbose=True):
    """
    Returns Keys, you can access:
                        Keys.public.n 
                            .public.g
                            .public.n_square
                            .private.lambd
                            .private.mu
    """
    # Generate keys for paillier
    if generate_new:
        public_key, private_key = paillier.generate_paillier_keypair(n_length=2048)
        n = public_key.n
        p = private_key.p
        q = private_key.q
        if verbose:
            print(f"n ({public_key.n.bit_length()}):  {public_key.n}")
            print(f"p ({private_key.p.bit_length()}):  {private_key.p}")
            print(f"q ({private_key.q.bit_length()}):  {private_key.q}")

        # using simpler implementation for (g, lambda, mu) (see paillier wikipedia article key generation)
        g = n + 1
        euler_totient = (p-1)*(q-1)         # replace lambda
        mu = pow(euler_totient, -1, n)
        if verbose:
            print(f"g ({g.bit_length()}):  {g}")
            print(f"euler_totient ({euler_totient.bit_length()}):  {euler_totient}")
            print(f"mu ({mu.bit_length()}):  {mu}") 

    else:
        # use pre-computed keys
        n = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156767
        p = 137397516278254663239726866649328438272497172712198430037546624647515417770993256224607179663782097405155585919186224912368912689987092085024864916625863986004190011294571016320531896670275905622285457944422186450485577817330011023154914210381730826259498368910855424071510567873875262223103536781743356764711
        q = 176848927162074462595704636463293622886938957050455393876610113990186370814431675413321957669896330144384443335853203830158783732140011632905016506498002423048478024401182275650004622463625186605838185059082819242930577934998247733589586685134794166719847357831469749895450960582462501232813670288012719501897

        # g = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959965269710922465262548828341138509786372705797502294771830110882552969910298655546490669918353671710285533456039285707492948419069894361429814515896814459547808304401372368479975170068863943438080814679348043287738485812146166554250955487778956844544755844751992223318142581805914904219738103941508103889347156768
        g = 2**1234
        euler_totient = 24298603348542999239474744469072890490956354295641370729036981648708630343434725324552857951009931558546313766563870577924497779647807993675137391985388865972325629382224451115147388661855418295796796426092117412381873609522077928268569523964665547055712043997759152822443548229142496038633810462117915959964955464479024933422992909635397164311546361372532118006196725814332208510070121559031989216338031857983916010030668064205891373472234326096586015391335681399251733336672726683199532344809536988586555705039782732792395990414225992198743278061328019762865406265480992968614844386447881974648024301034133270890160
        mu = 8915567752383628781438898187002797896548025900480737799095311841381836545755198503892372879726878495151035115946986868458012154448649583896132194358560329782831378798600255894543884351748301246095759638231762423081258773261447078148315461663411905258069603207263310818435311223030456445831047816378110749327580484779512120318259491191211823394214832953187276053506207701544252431583335833161276475407653180651152186091635887389297141653769732662414014629608293223179202238133723709179125878839638929208525481449388861597926415145013669009524453207751806355956198029749591583141643408193028947053783351959727470281524

    if verbose:
        print("n bitsize: ", n.bit_length())
        print("p bitsize: ", p.bit_length())
        print("q bitsize: ", q.bit_length())

    assert p*q == n
    assert euler_totient*mu % n == 1

    pub_key = Public_Key(n, g)
    priv_key = Private_Key(euler_totient, mu)

    return Keys(pub_key, priv_key)


def encrypt(pub_key: Public_Key, plaintext: int):
    r = random.randint(1, pub_key.n)

    cipher = pow(pub_key.g, plaintext, pub_key.n_square) * pow(r, pub_key.n, pub_key.n_square) % pub_key.n_square

    return cipher

def decrypt(keys: Keys, ciphertext: int):

    x = pow(ciphertext, keys.private.lambd, keys.public.n_square)
    Lx = (x - 1) // keys.public.n
    plaintext = (Lx * keys.private.mu) % keys.public.n

    return plaintext

# Just some helper functions
def ASCII_to_Int(message: str):
    return int.from_bytes(message.encode('utf-8'), byteorder='big', signed=False)

def Int_to_ASCII(integer: int, bytes_count: int = 4):
    return integer.to_bytes(bytes_count).decode('utf-8')




if __name__ == "__main__":
    keys = generate_keys(generate_new=False, verbose=True)

    plaintext_in = 12345
    ciphertext = encrypt(keys.public, plaintext_in)
    plaintext_out = decrypt(keys, ciphertext)
    print(f"In: {plaintext_in},\nCiphertext: {ciphertext},\nDecode: {plaintext_out}")

    print(f"n bits: {keys.public.n.bit_length()}")
    print(f"n^2 bits: {keys.public.n_square.bit_length()}")
    print(f"n^2 * (2^4096 - 1) bits {(keys.public.n_square * (2**4096 - 1)).bit_length()}")

    # for example: 
    # python paillier.py "Hello Paillier"
    if len(sys.argv) > 1:
        message = sys.argv[1]
        plaintext_in = ASCII_to_Int(message)
        
        ciphertext = encrypt(keys.public, plaintext_in)
        
        plaintext_out = decrypt(keys, ciphertext)

        print(Int_to_ASCII(plaintext_out, bytes_count=len(message)))
    
    
