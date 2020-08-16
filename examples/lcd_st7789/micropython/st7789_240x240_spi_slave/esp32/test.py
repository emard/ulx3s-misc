# code for micropython 1.12 on esp32

from machine import SPI,Pin,freq
from time import sleep_ms
from random import randint,seed

class test:
  def __init__(self):
    freq(240*1000*1000)
    self.busy = Pin(35,Pin.IN)
    self.csn = Pin(16,Pin.OUT)
    self.csn.on()
    self.spi = SPI(2, baudrate=20*1000000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,\
      mosi=Pin(25), sck=Pin(17), miso=Pin(33))

  @micropython.viper
  def line(self, x0:int,y0:int, x1:int,y1:int, color:int):
    y0+=80
    y1+=80
    while self.busy.value():
      continue
    self.csn.off()
    self.spi.write(bytearray([0, 0x1C,0xDC,0x00,0x00, x0>>8,x0, y0>>8,y0, x1>>8,x1, y1>>8,y1, color>>8,color]))
    self.csn.on()

  def prline(self, l:int):
    while self.busy.value():
      continue
    self.csn.off()
    self.spi.write(bytearray([0, 0x1C,0xDD,0x00,0x00]))
    for i in range(l):
      x=randint(0,239)
      if randint(0,10)==0:
        x|=32768 # discontinue polyline
      y=randint(0,239)+80
      if i==l-1:
        y|=32768 # last point
      self.spi.write(bytearray([x>>8,x,y>>8,y]))
    color = randint(0,0xFFFF)
    self.csn.on()
    self.csn.off()
    self.spi.write(bytearray([0, 0x1C,0xDE,0x00,0x00, color>>8,color]))
    self.csn.on()

  def pline(self, poly, color:int):
    while self.busy.value():
      continue
    self.csn.off()
    self.spi.write(bytearray([0, 0x1C,0xDD,0x00,0x00]))
    for x in poly:
      self.spi.write(bytearray([x>>8,x]))
    self.csn.on()
    self.csn.off()
    self.spi.write(bytearray([0, 0x1C,0xDE,0x00,0x00, color>>8,color]))
    self.csn.on()
  
  def plt(self):
    self.pline([0,0+80, 35,70+80, 80,45+80, 150,(200+80)|32768], -1)

  def pcl(self,color:int,len:int):
    self.csn.off()
    self.spi.write(bytearray([0, 0x1C,0xDE,0x00,0x00, color>>8,color, len>>8,len]))
    self.csn.on()

  def pcls(self):
    for i in range(240):
      self.pline([0,i+80, 239,(i+80)|32768], 0)

  def cls(self):
    for i in range(240):
      self.line(0,i, 239,i, 0)

  def main(self,n=100):
    print("st7789 spi slave test")
    self.cls()
    seed(0)
    for i in range(n):
      self.line(randint(0,239),randint(0,239), randint(0,239),randint(0,239), randint(0,0xFFFF))

run=test()
#run.main()
run.pcls()
run.prline(20)
