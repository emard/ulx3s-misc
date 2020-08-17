# code for micropython 1.12 on esp32

from machine import SPI,Pin,freq
from time import sleep_ms
from random import randint,seed
import vectorfont
import st7789poly

class test:
  def __init__(self):
    freq(240*1000*1000)
    self.busy = Pin(35,Pin.IN)
    self.csn = Pin(16,Pin.OUT)
    self.csn.on()
    self.spi = SPI(2, baudrate=20*1000000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,\
      mosi=Pin(25), sck=Pin(17), miso=Pin(33))
    self.vf=vectorfont.vectorfont(self.csn,self.busy,self.spi)
    self.pl=st7789poly.st7789poly(self.csn,self.busy,self.spi)

  def main(self):
    print("st7789 spi slave polyline test")
    self.pl.cls(0)
    #seed(0)
    for i in range(30):
      self.vf.text("0123456789012345678901234567890123456789",0,i*8) 
    self.pl.cls(0)
    for i in range(200):
      self.pl.polyline([randint(0,239),randint(0,239), randint(0,239),randint(0,239)], randint(0,0xFFFF))
    sleep_ms(500)
    self.pl.cls(0)
    self.vf.text("ABCČĆDĐEFGHIJKLMNOPQRSŠTUVWXYZŽ",0, 10)
    self.vf.text("abcčćdđefghijklmnopqrsštuvwxyzž",0, 20)
    self.vf.text("0123456789012345678901234567890123456789",0, 30)
    self.vf.text("ABCČĆDĐEFG",0,50,spacing=22,xscale=1024,yscale=1024,color=st7789poly.color565(255,255,0))
    self.vf.text("abcčćdđefg",0,80,spacing=22,xscale=1024,yscale=1024,color=st7789poly.color565(255,255,0))
    self.vf.text("0123456789",0,110,spacing=22,xscale=1024,yscale=1024,color=st7789poly.color565(0,255,255))
    self.vf.text("@!?#$%&\\~^|",0,140,spacing=22,xscale=1024,yscale=1024,color=st7789poly.color565(0,255,255))
    self.vf.text("8888888888888888888888888888888",0, 170)
    self.vf.text("@!?#$%&\\~^|",0,180,color=st7789poly.color565(255,255,255))
    self.vf.text("Accelerated polyline core!",0,190,color=st7789poly.color565(255,255,255))
    #for i in range(n):
    #  self.vf.polyline([randint(0,239),randint(0,239), randint(0,239),randint(0,239)], randint(0,0xFFFF))

run=test()
run.main()
