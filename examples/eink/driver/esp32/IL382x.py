# ESP32 micropython

# driver for e-paper/e-ink displays
# based on IL3820 or IL3829 chips:

# Waveshare BW 2.9" 296x128 IL3820
# PCB color: blue with white silkscreen

# Heltec BW 1.54" 200x200 IL3829
# Markings on flat cable:
# HINK-E0154A07-A1
# Date:2017-02-28
# SYX 1942
# PCB color: white with black silkscreen

from time import sleep_ms
from machine import Pin,SPI
from uctypes import addressof

DRIVER_OUTPUT_CONTROL                 = const(0x01)
BOOSTER_SOFT_START_CONTROL            = const(0x0C)
GATE_SCAN_START_POSITION              = const(0x0F)
DEEP_SLEEP_MODE                       = const(0x10)
DATA_ENTRY_MODE_SETTING               = const(0x11)
SW_RESET                              = const(0x12)
TEMPERATURE_SENSOR_SELECTION          = const(0x18)
TEMPERATURE_SENSOR_CONTROL            = const(0x1A)
MASTER_ACTIVATION                     = const(0x20)
DISPLAY_UPDATE_CONTROL_1              = const(0x21)
DISPLAY_UPDATE_CONTROL_2              = const(0x22)
WRITE_RAM                             = const(0x24)
WRITE_RAM_RED                         = const(0x26)
WRITE_VCOM_REGISTER                   = const(0x2C)
WRITE_LUT_REGISTER                    = const(0x32)
SET_DUMMY_LINE_PERIOD                 = const(0x3A)
SET_GATE_TIME                         = const(0x3B)
BORDER_WAVEFORM_CONTROL               = const(0x3C)
SET_RAM_X_ADDRESS_START_END_POSITION  = const(0x44)
SET_RAM_Y_ADDRESS_START_END_POSITION  = const(0x45)
SET_RAM_X_ADDRESS_COUNTER             = const(0x4E)
SET_RAM_Y_ADDRESS_COUNTER             = const(0x4F)
TERMINATE_FRAME_READ_WRITE            = const(0xFF)

class driver:
  def __init__(self, specific, dc, mosi, cs, clk, busy, reset=-1, miso=34, rotation=0):
    self.dc_pin=Pin(dc,Pin.OUT)
    self.cs_pin=Pin(cs,Pin.OUT)
    self.busy_pin=Pin(busy,Pin.IN)
    self.reset_pin=None
    if reset>=0:
      self.reset_pin=Pin(reset,Pin.OUT)
    self.spi=SPI(-1, baudrate=2000000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB, sck=Pin(clk), mosi=Pin(mosi), miso=Pin(miso))
    self.spibyte=bytearray(1)
    self.rb=bytearray(256) # reverse bits
    self.init_reverse_bits()
    if rotation==0:
      self.DATA_ENTRY=0
      self.X_START=specific.width-1
      self.Y_START=specific.height-1
      self.X_END=0
      self.Y_END=0
    if rotation==1:
      self.DATA_ENTRY=6
      self.X_START=specific.width-1
      self.Y_START=0
      self.X_END=0
      self.Y_END=specific.height-1
    if rotation==2:
      self.DATA_ENTRY=3
      self.X_START=0
      self.Y_START=0
      self.X_END=specific.width-1
      self.Y_END=specific.height-1
    if rotation==3:
      self.DATA_ENTRY=5
      self.X_START=0
      self.Y_START=specific.height-1
      self.X_END=specific.width-1
      self.Y_END=0
    self.width=specific.width
    self.height=specific.height
    self.specific=specific
    self.refresh=bytearray(1)

  @micropython.viper
  def init_reverse_bits(self):
    p8rb=ptr8(addressof(self.rb))
    for i in range(256):
      v=i
      r=0
      for j in range(8):
        r<<=1
        r|=v&1
        v>>=1
      p8rb[i]=r

  @micropython.viper
  def init(self):
    self.reset()
    self.send_command(DRIVER_OUTPUT_CONTROL)
    self.send_data(int(self.height)-1)
    self.send_data((int(self.height)-1) >> 8)
    self.send_data(0x00) # GD = 0, SM = 0, TB = 0
    if int(self.specific.IL)==3820:
      # waveshare 2.9" BW 128x296
      self.send_command(BOOSTER_SOFT_START_CONTROL)
      self.send_data(0xD7)
      self.send_data(0xD6)
      self.send_data(0x9D)
      self.send_command(WRITE_VCOM_REGISTER)
      self.send_data(0xA8)
      self.send_command(SET_DUMMY_LINE_PERIOD)
      self.send_data(0x1A) # 4 dummy lines per gate
      self.send_command(SET_GATE_TIME)
      self.send_data(0x08) # 2us per line
    if int(self.specific.IL)==3829:
      # heltec 1.54" BW 200x200
      self.send_command(BORDER_WAVEFORM_CONTROL)
      self.send_data(0x01)
      self.send_command(TEMPERATURE_SENSOR_SELECTION)
      self.send_data(0x80) # built-in temperature sensor
      self.send_command(DISPLAY_UPDATE_CONTROL_2) # Load Temperature and waveform setting
      self.send_data(0xB1)
      self.send_command(MASTER_ACTIVATION) 
      self.wait_until_idle()
    self.send_command(DATA_ENTRY_MODE_SETTING) # screen rotation
    self.send_data(self.DATA_ENTRY)
    self.set_full_refresh()

  @micropython.viper
  def set_lut(self, lut):
    p8=ptr8(addressof(lut))
    self.send_command(WRITE_LUT_REGISTER)
    for i in range(30):
      self.send_data(p8[i])

  @micropython.viper
  def _spi_transfer(self,data:int):
    p8=ptr8(addressof(self.spibyte))
    p8[0]=data
    self.cs_pin(False)
    self.spi.write(self.spibyte)
    self.cs_pin(True)

  @micropython.viper
  def send_command(self, command:int):
    self.dc_pin(False)
    self._spi_transfer(command)

  @micropython.viper
  def send_data(self, data:int):
    self.dc_pin(True)
    self._spi_transfer(data)

  @micropython.viper
  def wait_until_idle(self):
    while(self.busy_pin()): # 0: idle, 1: busy
      sleep_ms(100)

  @micropython.viper
  def reset(self):
    if self.reset_pin:
      self.reset_pin.on()
      sleep_ms(200)
      self.reset_pin.off()
      sleep_ms(10)
      self.reset_pin.on()
      sleep_ms(200)
    else:
      self.send_command(SW_RESET)
      self.wait_until_idle()

  @micropython.viper
  def set_memory_area(self,x_start:int,y_start:int,x_end:int,y_end:int):
    self.send_command(SET_RAM_X_ADDRESS_START_END_POSITION)
    self.send_data(x_start >> 3)
    self.send_data(x_end >> 3)
    self.send_command(SET_RAM_Y_ADDRESS_START_END_POSITION)
    self.send_data(y_start)
    self.send_data(y_start >> 8)
    self.send_data(y_end)
    self.send_data(y_end >> 8)

  @micropython.viper
  def set_memory_pointer(self,x:int,y:int):
    self.send_command(SET_RAM_X_ADDRESS_COUNTER)
    self.send_data(x >> 3)
    self.send_command(SET_RAM_Y_ADDRESS_COUNTER)
    self.send_data(y)
    self.send_data(y >> 8)
    self.wait_until_idle()

  @micropython.viper
  def write_frame(self,frame_buffer):
    self.set_memory_area(self.X_START,self.Y_START, self.X_END,self.Y_END)
    self.set_memory_pointer(self.X_START,self.Y_START)
    self.send_command(WRITE_RAM)
    p8=ptr8(addressof(frame_buffer))
    for i in range(int(len(frame_buffer))):
      self.send_data(p8[i])

  @micropython.viper
  def write_frame_rb(self,frame_buffer):
    p8=ptr8(addressof(frame_buffer))
    p8rb=ptr8(addressof(self.rb))
    self.send_command(WRITE_RAM)
    for i in range(int(len(frame_buffer))):
      self.send_data(p8rb[p8[i]])

  @micropython.viper
  def set_full_refresh(self):
    if self.specific.lut_full_refresh:
      self.set_lut(self.specific.lut_full_refresh)
    p8=ptr8(addressof(self.refresh))
    p8[0]=int(self.specific.full_refresh)

  @micropython.viper
  def set_partial_refresh(self):
    if self.specific.lut_partial_refresh:
      self.set_lut(self.specific.lut_partial_refresh)
    p8=ptr8(addressof(self.refresh))
    p8[0]=int(self.specific.partial_refresh)

  @micropython.viper
  def refresh_frame(self):
    self.send_command(DISPLAY_UPDATE_CONTROL_2)
    self.send_data(int(self.refresh[0]))
    self.send_command(MASTER_ACTIVATION)
    self.send_command(TERMINATE_FRAME_READ_WRITE)
    self.wait_until_idle()

  @micropython.viper
  def display_frame(self,frame_buffer):
    if int(self.DATA_ENTRY)&4: # fix missing framebuf.MONO_VMSB
      self.write_frame_rb(frame_buffer)
    else:
      self.write_frame(frame_buffer)
    self.refresh_frame()

  # after this, call epd.init() to awaken the module
  @micropython.viper
  def sleep(self):
    self.send_command(DEEP_SLEEP_MODE)
