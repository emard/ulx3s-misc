# micropython ESP32
# SPI CH376 test

# AUTHOR=EMARD
# LICENSE=BSD

# this code is SPI master to FPGA SPI slave

from machine import SPI, Pin
from micropython import const
from time import sleep_ms, sleep_us
from gc import collect

class ch376:
  def __init__(self):
    self.led = Pin(5, Pin.OUT)
    self.led.off()
    self.spi_channel = const(1)
    self.hwspi=SPI(self.spi_channel, baudrate=6000000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB, sck=Pin(16), mosi=Pin(4), miso=Pin(12))
    self.busy=Pin(0, Pin.IN)
    self.exist=0

  def wait(self):
    while self.busy.value():
      pass
  
  def reset(self):
    self.led.on()
    self.hwspi.write(bytearray([0x05]))
    self.led.off()
    self.wait()

  def get_ic_ver(self) -> int:
    self.led.on()
    self.hwspi.write(bytearray([0x01]))
    response = self.hwspi.read(1)[0]
    self.led.off()
    return response & 0x3F

  def check_exist(self,value:int) -> int:
    self.led.on()
    self.hwspi.write(bytearray([0x06,value]))
    response = self.hwspi.read(1)[0]
    self.led.off()
    if response == value ^ 0xFF:
      return 1
    else:
      return 0

  def set_usb_mode(self,mode:int) -> int:
    self.led.on()
    self.hwspi.write(bytearray([0x15,mode]))
    sleep_us(10)
    response = self.hwspi.read(1)[0]
    self.led.off()
    return response

  # works only during set_usb_mode(5)
  # 0x44: no device
  # 0x10: low-speed
  # 0x20: full-speed
  def get_dev_rate(self) -> int:
    self.led.on()
    self.hwspi.write(bytearray([0x0A,0x07]))
    response = self.hwspi.read(1)[0]
    self.led.off()
    return response

  # 0:full-speed 12Mbps, 2:low-speed 1.5 Mbps
  def set_usb_speed(self,speed:int):
    self.led.on()
    self.hwspi.write(bytearray([0x04,speed]))
    self.led.off()

  def set_usb_low_speed(self):
    self.led.on()
    self.hwspi.write(bytearray([0x0B,0x17,0xD8]))
    self.led.off()

  def auto_setup(self):
    self.led.on()
    self.hwspi.write(bytearray([0x4D]))
    self.led.off()

  # sets remote address
  def set_address(self,addr:int) -> int:
    self.led.on()
    self.hwspi.write(bytearray([0x45,addr]))
    response = self.hwspi.read(1)[0]
    self.led.off()
    return response

  # sets our address
  def set_our_address(self,addr:int):
    self.led.on()
    self.hwspi.write(bytearray([0x13,addr]))
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
    if len:
      data = self.hwspi.read(len)
    else:
      data = bytearray()
    self.led.off()
    return data

  def rd_usb_data(self):
    self.led.on()
    self.hwspi.write(bytearray([0x28]))
    len = self.hwspi.read(1)[0]
    if len:
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

  # token alternate 0x00/0x80
  # x: high 4 bits: endpoint, low 4 bits: operation 9=read
  def issue_token_x(self,token:int,x:int):
    self.led.on()
    self.hwspi.write(bytearray([0x4E,token,x]))
    self.led.off()

  def clr_stall(self,ep:int):
    self.led.on()
    self.hwspi.write(bytearray([0x41,ep]))
    self.led.off()

  def test_connect(self) -> int:
    self.led.on()
    self.hwspi.write(bytearray([0x16]))
    response = self.hwspi.read(1)[0]
    self.led.off()
    return response

  # enumerates but has some problem with reading
  def start(self):
    self.reset()
    self.wait()
    while True:
      sleep_ms(100)
      self.exist+=1
      if self.check_exist(self.exist):
        break
    print("CH376 v%d waits for hotplug of USB HID device" % self.get_ic_ver()) # my module is v3, albiero is v4
    self.set_usb_mode(5)  # host mode: CH376 turns module LED ON
    hotplug = 0x44
    while hotplug == 0x44:
      self.wait()
      hotplug = self.get_dev_rate()
    self.set_usb_mode(7)  # reset and host mode, mouse turns bottom LED ON
    sleep_ms(20)
    self.set_usb_mode(6)  # release from reset
    self.wait()
    if hotplug == 0x10: # low-speed device
      self.set_usb_speed(2) # 2:low-speed 1.5 Mbps
      print("hot-plugged USB low-speed 1.5 Mbps device")
    if hotplug == 0x20: # full-speed device
      self.set_usb_speed(0) # 0:full-speed 12Mbps
      print("hot-plugged USB full-speed 12 Mbps device")
    self.wait()
    self.auto_setup()
    self.wait()
    self.set_config(1) # turns ON USB mouse LED
    self.wait()
    #self.wr_usb_data(bytearray([0x21,0x0B,0,0,0,0,0,0])) # BOOTP compatible mouse, no wheel
    #self.issue_token_x(0,0x0D)
    #self.wait
    # HID request for device not to send reports if IDLE
    # only when user presses something the report will be send
    # some HID devices ignore this command and send idle reports anyway
    #self.wr_usb_data(bytearray([0x21,0x0A,0,0,0,0,0,0])) # SET IDLE 0
    #self.issue_token_x(0,0x0D) # 0x0D -> 0:EP0 D:WRITE
    #self.wait()
    #self.set_config(0) # verify that this turns OFF USB mouse LED
    #sleep_ms(200)
    #self.set_config(1) # turns ON USB mouse LED
    #sleep_ms(200)

  def reading(self):
    token = 0
    while True:
      self.issue_token_x(token,0x19) # 0x19 -> 1:EP1 9:READ
      token^=0x80
      self.wait()
      if self.get_status() != 0x14: # unplugged
        return
      d = self.rd_usb_data0()
      if len(d) > 0:
        print(len(d), end=":")
        for i in range(len(d)):
          print(" %02X" % d[i], end="")
        print("")
      collect()

def help():
  print("ch376.test()")

def test():
  u=ch376()
  while True:
    u.start()
    u.reading()

test()
