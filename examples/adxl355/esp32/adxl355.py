from machine import Pin,SPI
from micropython import const
from uctypes import addressof
from time import sleep_ms
from math import sqrt

TEMP_BIAS    = const(-1862) # temp bias at 25 deg C (more negative -> higher temp reading)
TEMP_SLOPE   = const(-905) # LSB/1000degC (more negative -> higher temp sensitivity reading)

#TEMP_BIAS    = const(0)
#TEMP_SLOPE   = const(1)

# 2,4,8 sensitivity g-range
ADXL_SENSE   = const(2)

# activity/inactivity treshold values
ACT_VALUE    = const(50)
INACT_VALUE  = const(50)

# activity/inactivity time
ACT_TIMER    = const(100)
INACT_TIMER  = const(10)

# registers
DEVID_AD     = 0x00
DEVID_MST    = 0x01
PARTID       = 0x02
REVID        = 0x03
STATUS       = 0x04
FIFO_ENTRIES = 0x05
TEMP2        = 0x06
TEMP1        = 0x07
XDATA3       = 0x08
XDATA2       = 0x09
XDATA1       = 0x0A
YDATA3       = 0x0B
YDATA2       = 0x0C
YDATA1       = 0x0D
ZDATA3       = 0x0E
ZDATA2       = 0x0F
ZDATA1       = 0x10
FIFO_DATA    = 0x11
OFFSET_X_H   = 0x1E
OFFSET_X_L   = 0x1F
OFFSET_Y_H   = 0x20
OFFSET_Y_L   = 0x21
OFFSET_Z_H   = 0x22
OFFSET_Z_L   = 0x23
ACT_EN       = 0x24
ACT_THRESH_H = 0x25
ACT_THRESH_L = 0x26
ACT_COUNT    = 0x27
FILTER       = 0x28
FIFO_SAMPLES = 0x29
INT_MAP      = 0x2A
SYNC         = 0x2B
RANGE        = 0x2C
POWER_CTL    = 0x2D
SELF_TEST    = 0x2E
RESET        = 0x2F

csn=Pin(17,Pin.OUT)
csn.on()
pin_sck=const(0)
pin_mosi=const(16)
pin_miso=const(35)
spi_channel=const(2) # the hardware available, sometimes stops working
#spi_channel=const(-1) # soft-spi, lower latency
# baudrate in Hz, range 0.1-10 MHz
bps=const(1000000)
# two initializations for reliabile start after ctrl-D
spi=SPI(spi_channel,baudrate=bps,polarity=0,phase=0,bits=8,firstbit=SPI.MSB,sck=Pin(pin_sck),mosi=Pin(pin_mosi),miso=Pin(pin_miso))
spi.deinit()
spi=SPI(spi_channel,baudrate=bps,polarity=0,phase=0,bits=8,firstbit=SPI.MSB,sck=Pin(pin_sck),mosi=Pin(pin_mosi),miso=Pin(pin_miso))

req=bytearray(1)
val=bytearray(1)
accelb=bytearray(9)
acceli=bytearray(12)
spi_fifoentries=bytearray(2)
spi_rdfifo=bytearray(10)
fifobuf32=bytearray(96*4)

@micropython.viper
def wr(addr:int,data):
  p8a=ptr8(addressof(req))
  p8a[0]=addr*2
  csn.off()
  spi.write(req)
  spi.write(data)
  csn.on()

@micropython.viper
def rd(addr:int,data):
  p8a=ptr8(addressof(req))
  p8a[0]=addr*2+1
  csn.off()
  spi.write(req)
  spi.readinto(data)
  csn.on()

def reset():
  wr(RESET,bytearray(0x52))

def test():
  expect=bytearray([0xAD,0x1D,0xED,0x01])
  devid=bytearray(4)
  mvdevid=memoryview(devid)
  rd(DEVID_AD,mvdevid)
  print(devid)
  if devid==expect:
    print("OK")
  else:
    print("Unexpected device")

def on():
  wr(POWER_CTL,bytearray(1))

# temperature in milli-celsius
def temp()->int:
  tb0=bytearray(2)
  tb1=bytearray([0,1])
  mvtb0=memoryview(tb0)
  # read multiple times, because values can be updated between byte reads
  while tb0!=tb1:
    tb1=tb0
    rd(TEMP2,mvtb0)
  t=(((tb0[0]&15)*256+tb0[1])+TEMP_BIAS)*TEMP_SLOPE
  return t

@micropython.viper
def rdaccel():
  p8b=ptr8(addressof(accelb))
  p8a=ptr8(addressof(acceli))
  rd(XDATA3,accelb)
  ix3=0
  ix4=0
  for i in range(3):
    p8a[ix4+3]=0
    if p8b[ix3]&0x80:
      p8a[ix4+3]=0xFF
    p8a[ix4+2]=p8b[ix3]
    p8a[ix4+1]=p8b[ix3+1]
    p8a[ix4+0]=p8b[ix3+2]
    ix3+=3
    ix4+=4

# i=1-3 range 1:+-2g, 2:+-4g, 3:+-8g
# high speed i2c, INT1,INT2 active high
@micropython.viper
def range(i:int):
  p8v=ptr8(addressof(val))
  p8v[0]=0xC0|i
  wr(RANGE,val)

# sample rate i=0-10, 4kHz/2^i, 0:4kHz ... 10:3.906Hz
@micropython.viper
def filter(i:int):
  p8v=ptr8(addressof(val))
  p8v[0]=i
  wr(FILTER,val)

@micropython.viper
def a(i:int)->int:
  p32a=ptr32(addressof(acceli))
  return p32a[i]>>4

def v():
  rdaccel()
  return sqrt(a(0)*a(0)+a(1)*a(1)+a(2)*a(2))

# read fifo to 32-bit signed buffer
@micropython.viper
def rdfifo32()->int:
  p8ent=ptr8(addressof(spi_fifoentries))
  p8rdf=ptr8(addressof(spi_rdfifo))
  p8buf=ptr8(addressof(fifobuf32))
  # read number of entries in the fifo
  p8ent[0]=11 # FIFO_ENTRIES*2+1 read request
  csn.off()
  spi.write_readinto(spi_fifoentries,spi_fifoentries)
  csn.on()
  n=p8ent[1]//3
  for i in range(n):
    p8rdf[0]=0x23 # FIFO_DATA*2+1 read request
    csn.off()
    spi.write_readinto(spi_rdfifo,spi_rdfifo)
    csn.on()
    for j in range(3):
      a=i*12+j*4
      b=1+j*3
      if p8rdf[b]&0x80:
        p8buf[a+3]=0xFF
      else:
        p8buf[a+3]=0
      for k in range(3):
        p8buf[a+2-k]=p8rdf[b+k]
  return n

# read value from 32-bit buffer
@micropython.viper
def fifo32(i:int)->int:
  p32buf=ptr32(addressof(fifobuf32))
  return p32buf[i]

# print 32-bit buffer
def prfifo32():
  if spi_fifoentries[1]<3:
    return
  for i in range(spi_fifoentries[1]//3*3):
    e=""
    if (i%12)==11:
      e="\n"
    print("%08x " % fifo32(i), end=e)
  if (i%12)!=11:
    print("")

def multird32(i=1000):
  for i in range(i):
    print(rdfifo32(),end=" ")
    #prfifo32()
  print("")
  prfifo32()

#reset()
#sleep_ms(1000)
test()
on()
range(1)
print(temp())
print(v())
filter(5)
multird32()
