from time import localtime,sleep_ms
from random import randint
import framebuf
from machine import Pin, I2C
from ntptime import settime
import mcp7940
import IL382x
import heltec_eink154bw200x200

i2c = I2C(sda=Pin(16), scl=Pin(17), freq=400000)
mcp = mcp7940.MCP7940(i2c)

rotation=2 # *90 deg
epd=IL382x.driver(
  dc=26,mosi=25,cs=15,clk=14,busy=5,\
  specific=heltec_eink154bw200x200.specific(),\
  rotation=rotation)
# initialize the frame buffer
fb_bytes = (epd.width*epd.height)//8
frame = bytearray(fb_bytes)
if rotation&1:
  fb=framebuf.FrameBuffer(frame, epd.height, epd.width, framebuf.MONO_VLSB)
else:
  fb=framebuf.FrameBuffer(frame, epd.width, epd.height, framebuf.MONO_HLSB)

ntp=0

def disp(t=None,color=0):
  fb.fill(0xFF)
  fb.text("Micropython!", 0,0, 0)
  fb.hline(0,10, 96, 0)
  #fb.line(0,10, 96,106, 0)
  if t:
    td=t
  else:
    td=mcp.time
  weekday=["MO","TU","WE","TH","FR","SA", "SU"]
  source=["MCP","NTP"]
  time_str="%04d-%02d-%02d %02d:%02d:%02d %02s %03s" % \
    (td[0],td[1],td[2],td[3],td[4],td[5],weekday[td[6]],source[ntp])
  fb.text(time_str, 0,40+(10*td[4])%120, color)
  epd.display_frame(frame)

def shutdown():
  epd.cs.on()
  for i in range(14):
    epd.dc.on()
    epd.dc.off()

def clock():
  epd.init()
  # first update will make screen clear
  epd.set_partial_refresh()
  #disp()
  # if shutdown was not successful, clock will be displayed
  # every 5 sec
  for i in range(3):
  #while False:
    td=mcp.time
    sec_prev=td[5]
    # update every 5 minutes
    #while td[5]>=sec_prev or (td[4]%5)!=0:
    # update every 5 seconds
    #while td[5]==sec_prev or (td[5]%5)!=0:
    # update every second
    while td[5]==sec_prev:
      sleep_ms(500)
      sec_prev=td[5]
      td=mcp.time
    disp(td,i&1)
  epd.sleep()
  mcp.battery_backup_enable(1)
  mcp.alarm0=td
  mcp.alarm0_every_minute()
  shutdown()

try:
  settime() # localtime() set from NTP
  mcp.time=localtime()
  mcp.start()
  print(mcp.time)
  ntp=1
except:
  print("NTP not available")

clock()
