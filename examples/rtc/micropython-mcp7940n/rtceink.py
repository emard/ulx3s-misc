import heltec_eink154bw200x200
from time import sleep_ms
from random import randint
import framebuf
from machine import Pin, I2C
import mcp7940

i2c = I2C(sda=Pin(16), scl=Pin(17), freq=400000)
mcp = mcp7940.MCP7940(i2c)

rotation=0 # *90 deg
epd=heltec_eink154bw200x200.HINK_E0154A07_A1(dc=26,mosi=25,cs=15,clk=14,busy=5,rotation=rotation)
# initialize the frame buffer
fb_size = (epd.width*epd.height)//8
frame = bytearray(fb_size)
if rotation&1:
  fb=framebuf.FrameBuffer(frame, epd.height, epd.width, framebuf.MONO_VLSB)
else:
  fb=framebuf.FrameBuffer(frame, epd.width, epd.height, framebuf.MONO_HLSB)

def disp():
  fb.fill(0xFF)
  fb.text("Micropython!", 0,0, 0)
  fb.hline(0,10, 96, 0)
  #fb.line(0,10, 96,106, 0)
  td=mcp.time
  weekday=["MO","TU","WE","TH","FR","SA", "SU"]
  time_str="%04d-%02d-%02d %02d:%02d:%02d %02s" % \
    (td[0],td[1],td[2],td[3],td[4],td[5],weekday[td[6]])
  fb.text(time_str, 0,40, 0)

  epd.init()
  epd.display_frame(frame)
  epd.sleep()

def clock():
  while True:
    sec_prev=0
    sec=0
    min=1
    while sec>=sec_prev or min%5!=0:
      sleep_ms(500)
      sec_prev=sec
      sec=mcp.time[5]
    disp()

disp()
