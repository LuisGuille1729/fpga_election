print("Hello")

import time
from machine import Pin

led = Pin("LED", Pin.OUT)

for i in range(10):
    time.sleep(1)
    led.toggle()
    print(i)
    
