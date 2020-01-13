# micropython ESP32
# SPI RAM test R/W

# AUTHOR=EMARD
# LICENSE=BSD

# this code is SPI master to FPGA SPI slave

from machine import SPI, Pin
from micropython import const

class spiram:
  def __init__(self):
    #self.filename = file_bin
    #print("FILE %s" % self.filename)
    #self.buflen = const(1024)
    #self.buf = bytearray(self.buflen)
    self.led = Pin(5, Pin.OUT)
    self.led.off()
    #self.binfile = open(self.filename, "rb")
    self.spi_channel = const(1)
    self.init_pinout_sd()
    self.spi_freq = const(2000000)
    self.hwspi=SPI(self.spi_channel, baudrate=self.spi_freq, polarity=0, phase=0, bits=8, firstbit=SPI.MSB, sck=Pin(self.gpio_sck), mosi=Pin(self.gpio_mosi), miso=Pin(self.gpio_miso))

  @micropython.viper
  def init_pinout_sd(self):
    self.gpio_sck  = const(16)
    self.gpio_mosi = const(4)
    self.gpio_miso = const(12)

  #@micropython.viper
  #def run(self):
  #  while(True):
  #    if self.count != self.count_prev:
  #      self.led.on()
  #      track = self.hwspi.read(1)[0]
  #      self.led.off()
  #      self.diskfile.seek(self.tracklen * track)
  #      self.diskfile.readinto(self.trackbuf)
  #      self.led.on()
  #      self.hwspi.write(self.trackbuf)
  #      self.led.off()
  #      self.count_prev = self.count
  #      #for i in range(16):
  #      #  print("%02X " % self.trackbuf[i], end="")
  #      #print("(track %d)" % track)

  def write(self, data, addr=0):
    self.led.on()
    self.hwspi.write(bytearray([0x00,(addr >> 8) & 0xFF, addr & 0xFF]))
    self.hwspi.write(data)
    self.led.off()

  def read(self, addr=0, length=1):
    self.led.on()
    self.hwspi.write(bytearray([0x01,(addr >> 8) & 0xFF, addr & 0xFF, 0x00]))
    result = bytearray(length)
    self.hwspi.readinto(result)
    self.led.off()
    return result

  # read from file -> write to SPI RAM
  def load_stream(self, filedata, addr=0, blocksize=1024):
    block = bytearray(blocksize)
    self.led.on()
    self.hwspi.write(bytearray([0x00,(addr >> 8) & 0xFF, addr & 0xFF]))
    while True:
      if filedata.readinto(block):
        self.hwspi.write(block)
      else:
        break
    self.led.off()

  # read from SPI RAM -> write to file
  def save_stream(self, filedata, addr=0, length=1024, blocksize=1024):
    bytes_saved = 0
    block = bytearray(blocksize)
    self.led.on()
    self.hwspi.write(bytearray([0x01,(addr >> 8) & 0xFF, addr & 0xFF, 0x00]))
    while bytes_saved < length:
      self.hwspi.readinto(block)
      filedata.write(block)
      bytes_saved += len(block)
    self.led.off()

def load(filename, addr=0):
  s=spiram()
  s.load_stream(open(filename, "rb"), addr)

def save(filename, addr=0, length=1024):
  s=spiram()
  s.save_stream(open(filename, "wb"), addr, length)

def help():
  print("spiram.load(\"file.bin\",addr=0)")
  print("spiram.save(\"file.bin\",addr=0,length=1024)")

# debug to manually write data and
#d.led.on(); d.hwspi.write(bytearray([0x00,0x11,0x22,0x33]));d.led.off()
#d=spiram()
#d.write(addr=0, data=bytearray([64,65,66,67]))
#print(d.read(addr=0, length=4))
#d.run()
