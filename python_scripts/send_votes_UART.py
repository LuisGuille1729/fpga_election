import serial
import sys
import time
import random

SERIAL_PORTNAME = "/dev/cu.usbserial-8874292301971"
BAUD = 4800

ser = serial.Serial(SERIAL_PORTNAME, BAUD)

def int_to_bytes(x: int) -> bytes:
    return x.to_bytes((x.bit_length() + 7) // 8, 'little') if x is not 0 else (0).to_bytes(1, 'little')
    
def int_from_bytes(xbytes: bytes) -> int:
    return int.from_bytes(xbytes, 'little')

def send_vote(candidate):
    print(f"Voting for candidate {candidate}")
    assert candidate in [0, 1], f"Candidate should be 0 or 1"
    
    message = candidate*(2**8 - 1)
    message = int_to_bytes(message)
    
    ser.write(message)
    
def send_byte(val):
    print(f"Sending {val}")
    message = int_to_bytes(int(val))
    ser.write(message) 
    



if __name__ == '__main__':
    if len(sys.argv) == 1:
        # Send all possible bytes
        for i in range(256):
            time.sleep(0.05)
            send_byte(i)
    elif len(sys.argv) == 2:
        
        if sys.argv[1] == 'interactive':
            while True:
                vote = input("Your vote [0,1]: ")
                send_vote(int(vote))
        else:
            send_vote(int(sys.argv[1]))
            # send_byte(sys.argv[1])
    else:
        # Send amount
        votes0 = int(sys.argv[1])
        votes1 = int(sys.argv[2])
        
        print(f"In random order:\n– sending {votes0} votes for candidate A\n- sending {votes1} votes for candidate B")
        
        all_votes0 = [0 for _ in range(votes0)]
        all_votes1 = [1 for _ in range(votes1)]
        
        all_votes = all_votes0 + all_votes1
        
        random.shuffle(all_votes)
        print(all_votes)
        
        for vote in all_votes:
            send_vote(vote)
        
        
            
                
        
        
