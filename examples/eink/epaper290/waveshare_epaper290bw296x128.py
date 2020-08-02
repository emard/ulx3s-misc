# ESP32 micropython
# for Waveshare BW 2.9" 296x128 IL3829

from time import sleep_ms
from machine import Pin,SPI
from uctypes import addressof

# Display resolution
EPD_WIDTH       = const(128)
EPD_HEIGHT      = const(296)

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

class epaper290:
  def __init__(self, dc, din, cs, clk, busy, rst, miso=34):
    self.dc_pin=Pin(dc,Pin.OUT)
    self.cs_pin=Pin(cs,Pin.OUT)
    self.reset_pin=Pin(rst,Pin.OUT)
    self.busy_pin=Pin(busy,Pin.IN)
    self.spi=SPI(-1, baudrate=2000000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB, sck=Pin(clk), mosi=Pin(din), miso=Pin(miso))
    self.width=EPD_WIDTH
    self.height=EPD_HEIGHT
    self.spibyte=bytearray(1)
    self.lut_full_update=bytearray([
      0x02, 0x02, 0x01, 0x11, 0x12, 0x12, 0x22, 0x22, 
      0x66, 0x69, 0x69, 0x59, 0x58, 0x99, 0x99, 0x88, 
      0x00, 0x00, 0x00, 0x00, 0xF8, 0xB4, 0x13, 0x51, 
      0x35, 0x51, 0x51, 0x19, 0x01, 0x00
    ])
    self.lut_parial_update=bytearray([
      0x10, 0x18, 0x18, 0x08, 0x18, 0x18, 0x08, 0x00, 
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
      0x00, 0x00, 0x00, 0x00, 0x13, 0x14, 0x44, 0x12, 
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ])  

  @micropython.viper
  def init(self):
    self.reset()
    self.send_command(DRIVER_OUTPUT_CONTROL);
    self.send_data(EPD_HEIGHT-1);
    self.send_data((EPD_HEIGHT-1) >> 8);
    self.send_data(0x00);                     # GD = 0; SM = 0; TB = 0;
    self.send_command(BOOSTER_SOFT_START_CONTROL);
    self.send_data(0xD7);
    self.send_data(0xD6);
    self.send_data(0x9D);
    self.send_command(WRITE_VCOM_REGISTER);
    self.send_data(0xA8);                     # VCOM 7C
    self.send_command(SET_DUMMY_LINE_PERIOD);
    self.send_data(0x1A);                     # 4 dummy lines per gate
    self.send_command(SET_GATE_TIME);
    self.send_data(0x08);                     # 2us per line
    self.send_command(DATA_ENTRY_MODE_SETTING);
    self.send_data(0x03);                     # X increment; Y increment
    self.set_lut(self.lut_full_update)
    self.wait_until_idle()

  @micropython.viper
  def set_lut(self, lut):
    p8=ptr8(addressof(lut))
    self.send_command(WRITE_LUT_REGISTER);
    for i in range(30):
      self.send_data(p8[i]);

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
    self.reset_pin.on()
    sleep_ms(200)
    self.reset_pin.off()
    sleep_ms(10)
    self.reset_pin.on()
    sleep_ms(200)

  @micropython.viper
  def set_memory_area(self,x_start:int,y_start:int,x_end:int,y_end:int):
    self.send_command(SET_RAM_X_ADDRESS_START_END_POSITION)
    self.send_data(x_start >> 3)
    self.send_data(x_end >> 3)
    self.send_command(SET_RAM_Y_ADDRESS_START_END_POSITION);
    self.send_data(y_start)
    self.send_data(y_start >> 8)
    self.send_data(y_end)
    self.send_data(y_end >> 8)

  @micropython.viper
  def set_memory_pointer(self,x:int,y:int):
    self.send_command(SET_RAM_X_ADDRESS_COUNTER)
    self.send_data(x >> 3)
    self.send_command(SET_RAM_Y_ADDRESS_COUNTER);
    self.send_data(y)
    self.send_data(y >> 8)
    self.wait_until_idle()

  @micropython.viper
  def write_frame(self,frame_buffer):
    self.set_memory_area(0,0, EPD_WIDTH-1,EPD_HEIGHT-1);
    self.set_memory_pointer(0,0)
    p8=ptr8(addressof(frame_buffer))
    self.send_command(WRITE_RAM)
    for i in range(int(len(frame_buffer))):
      self.send_data(p8[i])

  @micropython.viper
  def refresh_frame(self):
    self.send_command(DISPLAY_UPDATE_CONTROL_2)
    self.send_data(0xC4)
    self.send_command(MASTER_ACTIVATION)
    self.send_command(TERMINATE_FRAME_READ_WRITE)
    self.wait_until_idle()

  @micropython.viper
  def display_frame(self,frame_buffer):
    self.write_frame(frame_buffer)
    self.refresh_frame()

  # after this, call epd.init() to awaken the module
  @micropython.viper
  def sleep(self):
    self.send_command(DEEP_SLEEP_MODE)

  # color 0:black 1:white 
  @micropython.viper
  def set_pixel(self, frame_buffer, x:int, y:int, color:int):
    if x < 0 or x >= EPD_WIDTH or y < 0 or y >= EPD_HEIGHT:
      return
    p8=ptr8(addressof(frame_buffer))
    addr=(x+y*EPD_WIDTH)//8
    if color:
      p8[addr]|= 0x80 >> (x&7)
    else:
      p8[addr]&=(0x80 >> (x&7))^0xFF

  @micropython.viper
  def draw_line(self, frame_buffer, x0:int, y0:int, x1:int, y1:int, color:int):
    # Bresenham's line algorithm wiki (with bugs fixed)
    if x0<x1:
      dx=x1-x0
      sx=1
    else:
      dx=x0-x1
      sx=-1
    if y0<y1:
      dy=y0-y1
      sy=1
    else:
      dy=y1-y0
      sy=-1
    err=dx+dy
    while True:
      self.set_pixel(frame_buffer, x0,y0, color)
      if x0==x1 and y0==y1:
        return
      if (err+err >= dy):
        err += dy
        x0 += sx
        continue
      if (err+err <= dx):
        err += dx
        y0 += sy
