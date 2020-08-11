# code for micropython 1.12 on esp32

from random import randint, getrandbits

from machine import SPI,Pin
import st7789py as st7789
import time

def run():
    print("st7789")
    spi = SPI(2, baudrate=20000000, polarity=1, mosi=Pin(25), sck=Pin(17), miso=Pin(33))
    display = st7789.ST7789(
        spi, 240, 240,
        cs=Pin(32,Pin.OUT),
        reset=Pin(16, Pin.OUT),
        dc=Pin(26, Pin.OUT),
    )
    display.init()

    while True:
        display.fill(
            st7789.color565(0,0,0)
        )
        for i in range(20):
          display.line(120,120,randint(0,240),randint(0,240), \
            st7789.color565(
                getrandbits(8),
                getrandbits(8),
                getrandbits(8),
            )
          )
        # Pause 2 seconds.
        #time.sleep(2)

run()
