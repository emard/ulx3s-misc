# code for micropython 1.12 on esp32

from machine import SPI,Pin,freq
import time

class test:
  def __init__(self):
    freq(240*1000*1000)
    self.csn = Pin(16,Pin.OUT)
    self.csn.on()
    self.spi = SPI(2, baudrate=20*1000000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,\
      mosi=Pin(25), sck=Pin(17), miso=Pin(33))

  def main(self):
    print("st7789 spi slave test")
    self.csn.off()
    self.spi.write(bytearray([0, 0x1C,0xDC,0xFF,0xFF, 1,2,3,4]))
    self.csn.on()

run=test()
run.main()
