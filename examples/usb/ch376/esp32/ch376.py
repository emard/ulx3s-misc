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
    self.spi_channel = const(1)
    self.hwspi=SPI(self.spi_channel, baudrate=6000000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB, sck=Pin(16), mosi=Pin(4), miso=Pin(12))
  
  def reset(self):
    self.led.on()
    self.hwspi.write(bytearray([0x05]))
    self.led.off()
    sleep_ms(100)

  def check_exist(self,value:int) -> int:
    self.led.on()
    self.hwspi.write(bytearray([0x06,value]))
    response = self.hwspi.read(1)[0]
    self.led.off()
    if response == value ^ 0xFF:
      return 1
    else:
      return 0

  def set_usb_mode(self,mode:int):
    self.led.on()
    self.hwspi.write(bytearray([0x15,mode]))
    self.led.off()

  def auto_setup(self):
    self.led.on()
    self.hwspi.write(bytearray([0x4D]))
    self.led.off()

  # sets remote address
  def set_address(self,addr:int):
    self.led.on()
    self.hwspi.write(bytearray([0x45,addr]))
    self.led.off()

  # sets our address
  def set_our_address(self,addr:int):
    self.led.on()
    self.hwspi.write(bytearray([0x13,addr]))
    self.led.off()

  def set_usb_speed(self,speed:int):
    self.led.on()
    self.hwspi.write(bytearray([0x04,speed]))
    self.led.off()

  def set_usb_low_speed(self):
    self.led.on()
    self.hwspi.write(bytearray([0x0B,0x17,0xD8]))
    self.led.off()

  def set_config(self,config:int):
    self.led.on()
    self.hwspi.write(bytearray([0x49,config]))
    self.led.off()

  def get_status(self) -> int:
    self.led.on()
    self.hwspi.write(bytearray([0x22]))
    status = self.hwspi.read(1)[0]
    self.led.off()
    return status

  def rd_usb_data0(self):
    self.led.on()
    self.hwspi.write(bytearray([0x27]))
    len = self.hwspi.read(1)[0]
    if len > 0:
      data = self.hwspi.read(len)
    else:
      data = bytearray()
    self.led.off()
    return data

  def rd_usb_data(self):
    self.led.on()
    self.hwspi.write(bytearray([0x28]))
    len = self.hwspi.read(1)[0]
    if len > 0:
      data = self.hwspi.read(len)
    else:
      data = bytearray()
    self.led.off()
    return data

  def wr_usb_data(self,buffer):
    self.led.on()
    self.hwspi.write(bytearray([0x2C,len(buffer)]))
    self.hwspi.write(buffer)
    self.led.off()

  def issue_token_x(self,token:int,x:int):
    self.led.on()
    self.hwspi.write(bytearray([0x4E,token,x]))
    self.led.off()

  def test_connect(self) -> int:
    self.led.on()
    self.hwspi.write(bytearray([0x16]))
    response = self.hwspi.read(1)[0]
    self.led.off()
    return response

def help():
  print("ch376.test()")

def test():
  u=ch376()
  u.reset()
  if u.check_exist(0xAF):
    print("CHECK EXIST OK")
  else:
    print("CHECK EXIST FAIL")
  u.set_usb_mode(5) # host mode CH376 turns module LED ON
  sleep_ms(50)
  u.set_usb_mode(7) # reset and host mode, mouse turns bottom LED ON
  sleep_ms(20)
  u.set_usb_mode(6) # release from reset
  
  u.set_usb_speed(2) # low speed 1.5 Mbps
  u.auto_setup()

  #u.set_usb_low_speed()
  #u.set_address(1)
  #u.set_our_address(1)
  #u.set_config(1)
  #print("stat %02X" % u.get_status())
  #print("stat %02X" % u.get_status())
  #u.wr_usb_data(bytearray([0x21,0x0B,0,0,0,0,0,0])) # BOOTP compatibility mode
  #u.issue_token_x(0x80,0x0D)
  #sleep_ms(1)
  #print("stat %02X" % u.get_status())

  token = 0
  i = 0
  while True:
    u.issue_token_x(token,0x19)
    sleep_ms(1)
    u.get_status()
    token ^= 0x80
    d = u.rd_usb_data0()
    if (i & 1023) == 0:
      print(len(d),d)
    i+=1

test()
