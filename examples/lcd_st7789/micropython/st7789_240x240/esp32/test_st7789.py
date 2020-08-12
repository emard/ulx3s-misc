# code for micropython 1.12 on esp32

from random import randint, getrandbits

from machine import SPI,Pin,freq
import st7789py as st7789
import time
import vectorfont

class test:
  def __init__(self):
    freq(240*1000*1000)

  def line(self,a):
    self.display.line(a[0],a[1],a[2],a[3],st7789.color565(a[4],a[5],a[6]))

  def run(self):
    print("st7789")
    # NOTE 7-pin display doesn't have miso and cs pins
    spi = SPI(2, baudrate=26000000, polarity=1, mosi=Pin(25), sck=Pin(17), miso=Pin(33))
    self.display = st7789.ST7789(
        spi, 240, 240,
        reset=Pin(16, Pin.OUT),
        dc=Pin(26, Pin.OUT),
        xstart=0,
        ystart=320-240
    )
    self.display.init()
    vf = vectorfont.vectorfont(240,240,self.line)

    while True:
        self.display.fill(
            st7789.color565(0,0,0)
        )
        vf.text("123ABCdef",0,120,spacing=20,xscale=1024,yscale=1024)
        for i in range(100):
          self.display.line(120,120,randint(0,240),randint(0,240), \
            st7789.color565(
                getrandbits(8),
                getrandbits(8),
                getrandbits(8),
            )
          )
        time.sleep(2)

a=test()
a.run()
