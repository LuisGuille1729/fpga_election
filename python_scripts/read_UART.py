import serial
import sys
import time

SERIAL_PORTNAME = "/dev/ttyUSB1"
BAUD = 4800

ser = serial.Serial(SERIAL_PORTNAME, BAUD)

def read_UART():
    return ser.read()

while True:
    time.sleep(0.1)
    print(hex(int.from_bytes(ser.read(4),byteorder='little')))