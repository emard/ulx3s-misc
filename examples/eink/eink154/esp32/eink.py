import IL382x
import heltec_eink154bw200x200
from time import sleep_ms
from random import randint
import framebuf

rotation=0 # *90 deg
epd=IL382x.driver(
  dc=26,mosi=25,cs=16,clk=17,busy=5,\
  specific=heltec_eink154bw200x200.specific(),\
  rotation=rotation)
# initialize the frame buffer
fb_bytes = (epd.width*epd.height)//8
frame = bytearray(fb_bytes)
if rotation&1:
  fb=framebuf.FrameBuffer(frame, epd.height, epd.width, framebuf.MONO_VLSB)
else:
  fb=framebuf.FrameBuffer(frame, epd.width, epd.height, framebuf.MONO_HLSB)

def randline():
 fb.line(randint(0,epd.width),randint(0,epd.height), randint(0,epd.width),randint(0,epd.height), 0)

def run():
  #clear()
  #chequers()
  #epd.init()
  #epd.display_frame(frame)
  #epd.sleep()

  #sleep_ms(10000)
  
  fb.fill(0xFF)
  fb.text("Micropython!", 0,0, 0)
  fb.hline(0,10, 96, 0)
  fb.line(0,10, 96,106, 0)

  epd.init()
  epd.display_frame(frame)
  sleep_ms(1000)
  epd.set_partial_refresh()
  for i in range(10):
    randline()
    fb.text("%1d" % i, 40,20, 0)
    epd.display_frame(frame)
    sleep_ms(1000)
    fb.text("%1d" % i, 40,20, 1) # erase
  epd.sleep()

run()
