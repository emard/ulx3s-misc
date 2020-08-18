from machine import SPI, Pin, Timer
from uctypes import addressof
from time import localtime
from micropython import const
from math import pi,sin,cos
import st7789vfont
import st7789poly

class stclock:
  def __init__(self):
    self.width=const(240)
    self.height=const(240)
    self.busy = Pin(35,Pin.IN)
    self.csn = Pin(16,Pin.OUT)
    self.csn.on()
    self.spi = SPI(2, baudrate=20*1000000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,\
      mosi=Pin(25), sck=Pin(17), miso=Pin(33))
    self.vf=st7789vfont.st7789vfont(self.csn,self.busy,self.spi)
    self.pl=st7789poly.st7789poly(self.csn,self.busy,self.spi)
    self.t=localtime()
    self.pl.cls(0)
    self.timer=Timer(3)
    self.alloc_tick=self.tick
    self.timer.init(mode=Timer.PERIODIC, period=1000, callback=self.alloc_tick)

  def tick(self, timer):
    # erase last
    #self.text_clock(self.t,0)
    self.graph_clock(self.t,0)    
    self.t=localtime()
    # draw new
    #self.text_clock(self.t,1)
    self.graph_clock(self.t,1)

  # color: 0-black/erase 1-draw
  def graph_clock(self,t,color):
    x0=self.width//2
    y0=x0
    rhour=self.width*4//16
    rmin=self.width*6//16
    rsecond=self.width*7//16
    rmax=self.width//2
    rtick=self.width*7//16
    rnum=self.width*6//16
    # draw ticks
    color_tick = st7789poly.rgb565(255,255,255)
    color_num = st7789poly.rgb565(255,255,255)
    if color:
      color_hour = st7789poly.rgb565(255,255,0)    
      color_min = st7789poly.rgb565(0,255,255)
      color_second = st7789poly.rgb565(255,0,0)
    else:
      color_hour=0
      color_min=0
      color_second=0
    for i in range(12):
      ahour=i*pi/6
      self.pl.polyline([x0+int(rtick*sin(ahour)),y0-int(rtick*cos(ahour)), x0+int(rmax*sin(ahour)),y0-int(rmax*cos(ahour))], color_tick)
      num_str="%d" % ((i+11)%12+1)
      self.vf.text(num_str, x0+int(rnum*sin(ahour))-5*len(num_str)+1,y0-int(rnum*cos(ahour))-7, spacing=12, xscale=512,yscale=512, color=color_num)
    # draw hands
    ahour=(t[3]+t[4]/60)*pi/6
    amin=(t[4]+t[5]/60)*pi/30
    asecond=(t[5])*pi/30
    self.pl.polyline([x0,y0, x0+int(rhour*sin(ahour)),y0-int(rhour*cos(ahour))], color_hour)
    self.pl.polyline([x0,y0, x0+int(rmin*sin(amin)),y0-int(rmin*cos(amin))], color_min)
    self.pl.polyline([x0,y0, x0+int(rsecond*sin(asecond)),y0-int(rsecond*cos(asecond))], color_second)

  def text_clock(self,t,color):
    if color:
      color=-1
    weekday=["MO","TU","WE","TH","FR","SA", "SU"]
    time_str="%04d-%02d-%02d %02s  %02d:%02d:%02d" % \
      (t[0],t[1],t[2], weekday[t[6]], t[3],t[4],t[5])
    self.vf.text(time_str, 37,0, color=color)

run=stclock()
