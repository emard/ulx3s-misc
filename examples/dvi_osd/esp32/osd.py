# micropython ESP32
# OSD loader for retro computing

# AUTHOR=EMARD
# LICENSE=BSD

# this code is SPI master to FPGA SPI slave
# FPGA sends pulse to GPIO after BTN state is changed.
# on GPIO pin interrupt from FPGA:
# btn_state = SPI_read
# SPI_write(buffer)
# FPGA SPI slave will accept image and start it

from machine import SPI, Pin, SDCard, Timer
from micropython import const, alloc_emergency_exception_buf
from uctypes import addressof
from struct import unpack
import os
import gc
import ecp5

gpio_cs   = const(5)
gpio_sck  = const(25) # gn[11]
gpio_mosi = const(26) # gp[11]
gpio_miso = const(16)

screen_x = const(64)
screen_y = const(20)

cwd = "/"
exp_names = " KMGTE"
smark = bytearray([32,16,42]) # space, right triangle, asterisk

spi_read_irq = bytearray([1,0xF1,0,0,0,0,0])
spi_read_btn = bytearray([1,0xFB,0,0,0,0,0])
spi_result = bytearray(7)
spi_enable_osd = bytearray([0,0xFE,0,0,0,1])
spi_write_osd = bytearray([0,0xFD,0,0,0])
spi_channel = const(2)
spi_freq = const(3000000)

spi=SPI(spi_channel, baudrate=spi_freq, polarity=0, phase=0, bits=8, firstbit=SPI.MSB, sck=Pin(gpio_sck), mosi=Pin(gpio_mosi), miso=Pin(gpio_miso))
cs=Pin(gpio_cs,Pin.OUT)
cs.off()

alloc_emergency_exception_buf(100)

enable = bytearray(1)
timer = Timer(3)

@micropython.viper
def irq_handler( pin):
  p8result = ptr8(addressof(spi_result))
  cs.on()
  spi.write_readinto(spi_read_irq, spi_result)
  cs.off()
  btn_irq = p8result[6]
  if btn_irq&0x80: # BTN event IRQ flag
    cs.on()
    spi.write_readinto(spi_read_btn, spi_result)
    cs.off()
    btn = p8result[6]
    p8enable = ptr8(addressof(enable))
    if p8enable[0]&2: # wait to release all BTNs
      if btn==1:
        p8enable[0]&=1 # clear bit that waits for all BTNs released
    else: # all BTNs released
      if (btn&0x78)==0x78: # all cursor BTNs pressed at the same time
        show_dir() # refresh directory
        p8enable[0]=(p8enable[0]^1)|2;
        osd_enable(p8enable[0]&1)
      if p8enable[0]==1:
        if btn==9: # btn3 cursor up
          start_autorepeat(-1)
        if btn==17: # btn4 cursor down
          start_autorepeat(1)
        if btn==1:
          timer.deinit() # stop autorepeat
        if btn==33: # btn6 cursor left
          updir()
        if btn==65: # btn6 cursor right
          select_entry()

def start_autorepeat( i:int):
  global autorepeat_direction, move_dir_cursor, timer_slow
  autorepeat_direction=i
  move_dir_cursor(i)
  timer_slow=1
  timer.init(mode=Timer.PERIODIC, period=500, callback=autorepeat)

def autorepeat( timer):
  global timer_slow
  if timer_slow:
    timer_slow=0
    timer.init(mode=Timer.PERIODIC, period=30, callback=autorepeat)
  move_dir_cursor(autorepeat_direction)
  irq_handler(0) # catch stale IRQ

# init file browser
def init_fb():
  global fb_topitem, fb_cursor, fb_selected
  fb_topitem = 0
  fb_cursor = 0
  fb_selected = -1

def select_entry():
  global fb_selected, fb_topitem, fb_cursor, cwd
  if direntries[fb_cursor][1]: # is it directory
    oldselected = fb_selected - fb_topitem
    fb_selected = fb_cursor
    try:
      cwd = fullpath(direntries[fb_cursor][0])
    except:
      fb_selected = -1
    show_dir_line(oldselected)
    show_dir_line(fb_cursor - fb_topitem)
    init_fb()
    read_dir()
    show_dir()
  else:
    change_file()

def updir():
  global cwd
  if len(cwd) < 2:
    cwd = "/"
  else:
    s = cwd.split("/")[:-1]
    cwd = ""
    for name in s:
      if len(name) > 0:
        cwd += "/"+name
  init_fb()
  read_dir()
  show_dir()

def fullpath(fname):
  if cwd.endswith("/"):
    return cwd+fname
  else:
    return cwd+"/"+fname

def change_file():
  global fb_selected, fb_topitem, fb_cursor
  oldselected = fb_selected - fb_topitem
  fb_selected = fb_cursor
  try:
    filename = fullpath(direntries[fb_cursor][0])
  except:
    filename = False
    fb_selected = -1
  show_dir_line(oldselected)
  show_dir_line(fb_cursor - fb_topitem)
  if filename:
    if filename.endswith(".bit"):
      spi_request.irq(handler=None)
      timer.deinit()
      enable[0]=0
      osd_enable(0)
      spi.deinit()
      tap=ecp5.ecp5()
      tap.prog_stream(open(filename,"rb"),blocksize=1024)
      if filename.endswith("_sd.bit"):
        os.umount("/sd")
        for i in bytearray([2,4,12,13,14,15]):
          p=Pin(i,Pin.IN)
          a=p.value()
          del p,a
      result=tap.prog_close()
      del tap
      gc.collect()
      #os.mount(SDCard(slot=3),"/sd") # BUG, won't work
      init_spi() # because of ecp5.prog() spi.deinit()
      spi_request.irq(trigger=Pin.IRQ_FALLING, handler=irq_handler_ref)
      irq_handler(0) # handle stuck IRQ
    if filename.endswith(".z80"):
      enable[0]=0
      osd_enable(0)
      import ld_zxspectrum
      s=ld_zxspectrum.ld_zxspectrum(spi,cs)
      s.loadz80(filename)
      del s
      gc.collect()
    if filename.endswith(".nes"):
      import ld_zxspectrum
      s=ld_zxspectrum.ld_zxspectrum(spi,cs)
      s.ctrl(1)
      s.ctrl(0)
      s.load_stream(open(filename,"rb"),addr=0,maxlen=0x101000)
      del s
      gc.collect()
      enable[0]=0
      osd_enable(0)
    if filename.endswith(".ora") or filename.endswith(".orao"):
      enable[0]=0
      osd_enable(0)
      import ld_orao
      s=ld_orao.ld_orao(spi,cs)
      s.loadorao(filename)
      del s
      gc.collect()
    if filename.endswith(".vsf"):
      enable[0]=0
      osd_enable(0)
      import ld_vic20
      s=ld_vic20.ld_vic20(spi,cs)
      s.loadvsf(filename)
      del s
      gc.collect()
    if (filename.find("vic20")>=0 or filename.find("VIC20")>=0) and (filename.endswith(".prg") or filename.endswith(".PRG")):
      enable[0]=0
      osd_enable(0)
      import ld_vic20
      s=ld_vic20.ld_vic20(spi,cs)
      s.loadprg(filename)
      del s
      gc.collect()
    if (filename.find("c64")>=0 or filename.find("C64")>=0) and (filename.endswith(".prg") or filename.endswith(".PRG")):
      enable[0]=0
      osd_enable(0)
      import ld_c64
      s=ld_c64.ld_c64(spi,cs)
      s.loadprg(filename)
      del s
      gc.collect()

@micropython.viper
def osd_enable( en:int):
  pena = ptr8(addressof(spi_enable_osd))
  pena[5] = en&1
  cs.on()
  spi.write(spi_enable_osd)
  cs.off()

@micropython.viper
def osd_print( x:int, y:int, i:int, text):
  p8msg=ptr8(addressof(spi_write_osd))
  a=0xF000+(x&63)+((y&31)<<6)
  p8msg[2]=i
  p8msg[3]=a>>8
  p8msg[4]=a
  cs.on()
  spi.write(spi_write_osd)
  spi.write(text)
  cs.off()

@micropython.viper
def osd_cls():
  p8msg=ptr8(addressof(spi_write_osd))
  p8msg[3]=0xF0
  p8msg[4]=0
  cs.on()
  spi.write(spi_write_osd)
  spi.read(1280,32)
  cs.off()

# y is actual line on the screen
def show_dir_line( y):
  if y < 0 or y >= screen_y:
    return
  mark = 0
  invert = 0
  if y == fb_cursor - fb_topitem:
    mark = 1
    invert = 1
  if y == fb_selected - fb_topitem:
    mark = 2
  i = y+fb_topitem
  if i >= len(direntries):
    osd_print(0,y,0,"%64s" % "")
    return
  if direntries[i][1]: # directory
    osd_print(0,y,invert,"%c%-57s     D" % (smark[mark],direntries[i][0]))
  else: # file
    mantissa = direntries[i][2]
    exponent = 0
    while mantissa >= 1024:
      mantissa >>= 10
      exponent += 1
    osd_print(0,y,invert,"%c%-57s %4d%c" % (smark[mark],direntries[i][0], mantissa, exp_names[exponent]))

def show_dir():
  for i in range(screen_y):
    show_dir_line(i)

def move_dir_cursor( step):
  global fb_cursor, fb_topitem
  oldcursor = fb_cursor
  if step == 1:
    if fb_cursor < len(direntries)-1:
      fb_cursor += 1
  if step == -1:
    if fb_cursor > 0:
      fb_cursor -= 1
  if oldcursor != fb_cursor:
    screen_line = fb_cursor - fb_topitem
    if screen_line >= 0 and screen_line < screen_y: # move cursor inside screen, no scroll
      show_dir_line(oldcursor - fb_topitem) # no highlight
      show_dir_line(screen_line) # highlight
    else: # scroll
      if screen_line < 0: # cursor going up
        screen_line = 0
        if fb_topitem > 0:
          fb_topitem -= 1
          show_dir()
      else: # cursor going down
        screen_line = screen_y-1
        if fb_topitem+screen_y < len(direntries):
          fb_topitem += 1
          show_dir()

def read_dir():
  global direntries
  direntries = []
  ls = sorted(os.listdir(cwd))
  for fname in ls:
    stat = os.stat(fullpath(fname))
    if stat[0] & 0o170000 == 0o040000:
      direntries.append([fname,1,0]) # directory
    else:
      direntries.append([fname,0,stat[6]]) # file
    gc.collect()

def ctrl(i):
  cs.on()
  spi.write(bytearray([0, 0xFF, 0xFF, 0xFF, 0xFF, i]))
  cs.off()

def peek(addr,length):
  ctrl(4)
  ctrl(6)
  cs.on()
  spi.write(bytearray([1,(addr >> 24) & 0xFF, (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF, 0]))
  b=bytearray(length)
  spi.readinto(b)
  cs.off()
  ctrl(4)
  ctrl(0)
  return b

def poke(addr,data):
  ctrl(4)
  ctrl(6)
  cs.on()
  spi.write(bytearray([0,(addr >> 24) & 0xFF, (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF]))
  spi.write(data)
  cs.off()
  ctrl(4)
  ctrl(0)

# initialization
init_fb()
read_dir()
irq_handler(0) # service eventual pending/stale IRQ
# activate IRQ service
irq_handler_ref = irq_handler # allocation happens here
spi_request = Pin(0, Pin.IN, Pin.PULL_UP)
spi_request.irq(trigger=Pin.IRQ_FALLING, handler=irq_handler_ref)

#os.mount(SDCard(slot=3),"/sd")
#ecp5.prog("/sd/vic20/bitstreams/ulx3s_vic20_32K_85f.bit")
#gc.collect()
