#from machine import Pin,PWM
#pps=PWM(Pin(5),freq=1,duty=102)

from machine import Pin,Timer
from time import sleep_ms
pin=Pin(5,Pin.OUT)
@micropython.viper
def tick(x):
  pin.on()
  sleep_ms(100)
  pin.off()

timer=Timer(3)
timer.init(mode=Timer.PERIODIC, period=1000, callback=tick)
