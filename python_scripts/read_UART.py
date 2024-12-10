import serial
import sys
import time

SERIAL_PORTNAME = "/dev/cu.usbserial-8874292301971"
BAUD = 4800

ser = serial.Serial(SERIAL_PORTNAME, BAUD)

def read_UART():
    return ser.read()

while True:
    time.sleep(0.1)
    print(ser.read(1))