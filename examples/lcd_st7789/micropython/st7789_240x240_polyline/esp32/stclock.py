from machine import SPI, Pin, Timer
from uctypes import addressof
from time import localtime

class stclock:
  def __init__(self):
    self.timer=Timer(3)
    self.alloc_tick=self.tick
    self.timer.init(mode=Timer.PERIODIC, period=1000, callback=self.alloc_tick)

  def tick(self, timer):
    print("Tick")

run=stclock()
