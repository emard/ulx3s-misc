from time import localtime,sleep_ms
from ntptime import settime
from random import randint
import framebuf
from math import sin,cos,pi
from machine import Pin, I2C
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

def graphic(t,color):
  x0=epd.width//2
  y0=x0
  rhour=epd.width*4//16
  rmin=epd.width*6//16
  rmax=epd.width//2
  rtick=epd.width*7//16
  # draw ticks
  for i in range(12):
    ahour=i*pi/6
    fb.line(x0+int(rtick*sin(ahour)),y0-int(rtick*cos(ahour)), x0+int(rmax*sin(ahour)),y0-int(rmax*cos(ahour)), color)
  # draw hands
  ahour=(t[3]+t[4]/60)*pi/6
  amin=(t[4]+t[5]/60)*pi/30
  fb.line(x0,y0, x0+int(rhour*sin(ahour)),y0-int(rhour*cos(ahour)), color)
  fb.line(x0,y0, x0+int(rmin*sin(amin)),y0-int(rmin*cos(amin)), color)

def draw_clock(t=None,color=0):
  fb.fill(0xFF)
  if t:
    td=t
  else:
    td=mcp.time
  weekday=["MO","TU","WE","TH","FR","SA", "SU"]
  source=["MCP","NTP"]
  time_str="%04d-%02d-%02d %02s %02d:%02d:%02d %03s" % \
    (td[0],td[1],td[2], weekday[td[6]], td[3],td[4],td[5], source[ntp])
  fb.text(time_str, 0,42+(10*td[4])%120, color)
  graphic(td,color)

def shutdown():
  epd.cs.on()
  for i in range(500):
    epd.dc.on()
    epd.dc.off()
    sleep_ms(2)

def clock():
  epd.init()
  td=mcp.time
  # wait for next minute
  while td[5]!=0:
    sleep_ms(500)
    td=mcp.time
  if td[4]:
    epd.set_partial_refresh()
    # draw previous content to be faded
    td_prev=(td[0],td[1],td[2],td[3],(td[4]+59)%60,td[5],td[6])
    draw_clock(td_prev,0)
    epd.write_frame(frame,IL382x.WRITE_RAM_RED) # to fade previous content
  # draw new content
  draw_clock(td,0)
  epd.write_frame(frame,IL382x.WRITE_RAM)
  epd.refresh_frame()
  epd.sleep()
  mcp.alarm0=td
  mcp.battery_backup_enable(1)
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
