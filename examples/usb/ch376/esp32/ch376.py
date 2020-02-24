# micropython ESP32
# SPI CH376 test

# AUTHOR=EMARD
# LICENSE=BSD

# this code is SPI master to FPGA SPI slave

from machine import SPI, Pin
from micropython import const
from time import sleep_ms

class ch376:
  def __init__(self):
    self.led = Pin(5, Pin.OUT)
    self.led.off()
    self.spi_channel = const(-1)
    self.hwspi=SPI(self.spi_channel, baudrate=100, polarity=0, phase=0, bits=8, firstbit=SPI.MSB, sck=Pin(16), mosi=Pin(4), miso=Pin(12))

def help():
  print("ch376.test()")

def test():
  s=ch376()

  s.led.on()
  buf = bytearray([0x05]) # RESET
  s.hwspi.write_readinto(buf,buf)
  print(buf)
  s.led.off()
  
  sleep_ms(36)

  s.led.on()
  buf = bytearray([0x06,0x0F]) # CHECK_EXIST
  s.hwspi.write_readinto(buf,buf)
  print(buf)
  buf=s.hwspi.read(1)
  print(buf)
  s.led.off()

  #print("%02X" % r[0])

  # debug to manually write and read 4 bytes
#d=spiram.spiram()
#d.led.on(); d.hwspi.write(bytearray([0x00,0x00,0x00,0x40,0x41,0x42,0x43])); d.led.off()
#d.led.on(); d.hwspi.write(bytearray([0x01,0x00,0x00,0x00])); print(d.hwspi.read(4)); d.led.off()

test()
