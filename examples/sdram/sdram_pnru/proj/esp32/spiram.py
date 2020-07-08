# micropython ESP32
# SPI RAM test R/W

# AUTHOR=EMARD
# LICENSE=BSD

# this code is SPI master to FPGA SPI slave

import os, gc
from machine import SPI, Pin, SDCard
from micropython import const
from struct import unpack
from uctypes import addressof

class spiram:
  def __init__(self):
    self.led = Pin(5,Pin.OUT)
    self.led.off()
    self.spi_channel = const(2)
    self.init_pinout_sd()
    self.spi_freq = const(200000)
    self.hwspi=SPI(self.spi_channel, baudrate=self.spi_freq, polarity=0, phase=0, bits=8, firstbit=SPI.MSB, sck=Pin(self.gpio_sck), mosi=Pin(self.gpio_mosi), miso=Pin(self.gpio_miso))

  @micropython.viper
  def init_pinout_sd(self):
    self.gpio_sck  = const(16)
    self.gpio_mosi = const(4)
    self.gpio_miso = const(12)

  # read from file -> write to SPI RAM
  def load_stream(self, filedata, addr=0, maxlen=0x10000, blocksize=1024):
    block = bytearray(blocksize)
    # Request load
    self.led.on()
    self.hwspi.write(bytearray([0,(addr >> 24) & 0xFF, (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF]))
    bytes_loaded = 0
    while bytes_loaded < maxlen:
      if filedata.readinto(block):
        self.hwspi.write(block)
        bytes_loaded += blocksize
      else:
        break
    self.led.off()

  # read from SPI RAM -> write to file
  def save_stream(self, filedata, addr=0, length=1024, blocksize=1024):
    bytes_saved = 0
    block = bytearray(blocksize)
    # Request save
    self.led.on()
    self.hwspi.write(bytearray([1,(addr >> 24) & 0xFF, (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF, 0]))
    while bytes_saved < length:
      self.hwspi.readinto(block)
      filedata.write(block)
      bytes_saved += len(block)
    self.led.off()

  def ctrl(self,i):
    self.led.on()
    self.hwspi.write(bytearray([0, 0xFF, 0xFF, 0xFF, 0xFF, i]))
    self.led.off()

  def cpu_halt(self):
    self.ctrl(2)

  def cpu_continue(self):
    self.ctrl(0)

def load(filename, addr=0):
  s=spiram()
  s.cpu_halt()
  s.load_stream(open(filename, "rb"), addr=addr)
  s.cpu_continue()

def save(filename, addr=0, length=0x8000):
  s=spiram()
  f=open(filename, "wb")
  s.cpu_halt()
  s.save_stream(f, addr, length)
  s.cpu_continue()
  f.close()

def ctrl(i):
  s=spiram()
  s.led.on()
  s.hwspi.write(bytearray([0, 0xFF, 0xFF, 0xFF, 0xFF, i]))
  s.led.off()
  
def peek(addr,length=1):
  s=spiram()
  #s.cpu_halt()
  s.led.on()
  s.hwspi.write(bytearray([1,(addr >> 24) & 0xFF, (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF, 0]))
  b=bytearray(length)
  s.hwspi.readinto(b)
  s.led.off()
  #s.cpu_continue()
  return b

def poke(addr,data):
  s=spiram()
  #s.cpu_halt()
  s.led.on()
  s.hwspi.write(bytearray([0,(addr >> 24) & 0xFF, (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF]))
  s.hwspi.write(data)
  s.led.off()
  #s.cpu_continue()

def help():
  print("spiram.load(\"file.bin\",addr=0)")
  print("spiram.save(\"file.bin\",addr=0,length=0x8000)")

os.mount(SDCard(slot=3),"/sd")
#ecp5.prog("/sd/msx/bitstreams/ulx3s_85f_msx1.bit")
gc.collect()
