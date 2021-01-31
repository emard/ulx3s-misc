from machine import Pin,SPI
from micropython import const
from time import sleep_ms

TEMP_BIAS    = const(1852) # temp bias at 25 deg C
TEMP_SLOPE   = const(-905) # LSB/1000degC

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
sck=Pin(0,Pin.OUT)
mosi=Pin(16,Pin.OUT)
miso=Pin(35,Pin.IN)
spi_channel=const(2) # the hardware available
#spi_channel=const(-1) # soft-spi
# baudrate in Hz, range 0.1-10 MHz
spi=SPI(spi_channel,baudrate=1000000,polarity=0,phase=0,bits=8,firstbit=SPI.MSB,sck=sck,mosi=mosi,miso=miso)

def wr(addr:int,data):
  csn.off()
  spi.write(bytearray([addr*2]))
  spi.write(data)
  csn.on()

def rd(addr:int,data):
  csn.off()
  spi.write(bytearray([addr*2+1]))
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

# temperature in milli-celsius
def temp()->int:
  tb0=bytearray(2)
  tb1=bytearray([0,1])
  mvtb0=memoryview(tb0)
  # read multiple times, because values can be updated between byte reads
  while tb0!=tb1:
    tb1=tb0
    rd(TEMP2,mvtb0)
  t=((tb0[0]&15)*256+tb0[1])*TEMP_SLOPE+TEMP_BIAS
  return t

#def accel(xyz):
#  tb=bytearray(9)
#  mvtb=memoryview(tb)
#  rd(XDATA3,mvtb)
#  for i in range(3):
#    xyz[i]=(tb[i*3]&0x80 ? 0xFF000000 : 0) | (tb[i*3]<<16) | (tb[i*3+1]<<8) | (tb[i*3+2]);

#reset()
#sleep_ms(1000)
test()
