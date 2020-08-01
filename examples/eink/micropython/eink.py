import heltec_eink154bw200x200
from time import sleep_ms
from random import randint

epd=heltec_eink154bw200x200.HINK_E0154A07_A1(dc=26,mosi=25,cs=16,clk=17,busy=5)
# initialize the frame buffer
fb_size = (epd.width*epd.height)//8
frame = bytearray(fb_size)

def clear():
  for i in range(fb_size):
    frame[i]=0xFF

def chequers():
  for x in range(epd.width):
    for y in range(epd.height):
      epd.set_pixel(frame, x,y, ((x//5)^(y//5))&1)

def lines():
  i=0
  while i<epd.width:
    epd.draw_line(frame, 0,0, i,epd.height-10, 0)
    i+=8

def randlines(n):
  for i in range(n):
    epd.draw_line(frame, randint(0,epd.width),randint(0,epd.height), randint(0,epd.width),randint(0,epd.height), 0)
    i+=8

def run():
  #clear()
  #chequers()
  #epd.init()
  #epd.display_frame(frame)
  #epd.sleep()

  #sleep_ms(10000)

  clear()
  randlines(100)
  epd.init()
  epd.display_frame(frame)
  epd.sleep()

run()
