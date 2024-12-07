import serial
import sys
import time

SERIAL_PORTNAME = "/dev/cu.usbserial-8874292301971"
BAUD = 9600

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
    
def read_UART():
    return ser.read()

# assert int(sys.argv[1]) in [0, 1], f"{sys.argv}"
# send_vote(int(sys.argv[1]))

# send_byte(sys.argv[1])
for i in range(256):
    time.sleep(0.1)
    send_byte(i)

print(ser.read())
    
