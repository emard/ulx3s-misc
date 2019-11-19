# Micropython ESP32 and passthru bitstream

from time import sleep_ms
from machine import SPI,Pin
from micropython import const

class oled:

  def __init__(self):
    self.spi_channel = const(-1) # -1 soft, 1:sd, 2:jtag
    self.spi_freq = const(1000000) # Hz SPI frequency
    self.oled_ssd1331_commands()
    self.init_pinout_oled()
    self.init_spi()
    self.init_bitbang()
#    self.oled_init()

  def init_pinout_oled(self):
    self.gpio_csn = const(17)
    self.gpio_resn = const(26)
    self.gpio_dc = const(16)
    self.gpio_sck = const(14)
    self.gpio_mosi = const(15) # 13 or 15
    self.gpio_miso = const(2)
  
  def init_spi(self):
    self.oled_spi=SPI(self.spi_channel, baudrate=self.spi_freq, polarity=0, phase=0, bits=8, firstbit=SPI.MSB, sck=Pin(self.gpio_sck), mosi=Pin(self.gpio_mosi), miso=Pin(self.gpio_miso))

  def init_bitbang(self):
    self.dc=Pin(self.gpio_dc,Pin.OUT)
    self.resn=Pin(self.gpio_resn,Pin.OUT)
    self.csn=Pin(self.gpio_csn,Pin.OUT)

  def oled_ssd1331_commands(self):
    self.C_OLED_NOP1 = 0xBC
    self.C_OLED_NOP2 = 0xBD # delay nop
    self.C_OLED_NOP3 = 0xE3
    self.C_OLED_SET_DISPLAY_OFF = 0xAE # 10101110
    self.C_OLED_SET_REMAP_COLOR = 0xA0
    self.C_OLED_ULX3S_REMAP = 0x22 # 0b00100010 # A[7:6] = 00; 256 color. A[7:6] = 01; 65k color format rotation for ULX3S; A[1] = 1 scan right to left
    self.C_OLED_SET_DISPLAY_START_LINE = 0xA1
    self.C_OLED_SET_DISPLAY_OFFSET = 0xA1
    self.C_OLED_SET_DISPLAY_MODE_NORMAL = 0xA4
    self.C_OLED_SET_MULTIPLEX_RATIO = 0xA8
    self.C_OLED_SET_MASTER_CONFIGURATION = 0xAD
    self.C_OLED_SET_POWER_SAVE_MODE = 0xB0
    self.C_OLED_SET_PHASE_1_AND_2_PERIOD_ADJUSTMENT = 0xB1
    self.C_OLED_SET_DISPLAY_CLOCK_DIVIDER = 0xF0
    self.C_OLED_SET_PRECHARGE_A = 0x8A
    self.C_OLED_SET_PRECHARGE_B = 0x8B
    self.C_OLED_SET_PRECHARGE_C = 0x8C
    self.C_OLED_SET_PRECHARGE_LEVEL = 0xBB
    self.C_OLED_SET_VCOMH = 0xBE
    self.C_OLED_SET_MASTER_CURRENT_CONTROL = 0x87
    self.C_OLED_SET_CONTRAST_COLOR_A = 0x81
    self.C_OLED_SET_CONTRAST_COLOR_B = 0x82
    self.C_OLED_SET_CONTRAST_COLOR_C = 0x83
    self.C_OLED_SET_COLUMN_ADDRESS = 0x15
    self.C_OLED_SET_ROW_ADDRESS = 0x75
    self.C_OLED_SET_DISPLAY_ON = 0xAF

    self.oled_init_sequence = bytearray([self.C_OLED_NOP1, # 0, 10111100
    self.C_OLED_SET_DISPLAY_OFF, # 1, 10101110
    self.C_OLED_SET_REMAP_COLOR, self.C_OLED_ULX3S_REMAP, # 2
    self.C_OLED_SET_DISPLAY_START_LINE, 0x00, # 4
    self.C_OLED_SET_DISPLAY_OFFSET, 0x00, # 6
    self.C_OLED_SET_DISPLAY_MODE_NORMAL, # 8
    self.C_OLED_SET_MULTIPLEX_RATIO, 0x3F, # 0b00111111, # 9, 15-16
    self.C_OLED_SET_MASTER_CONFIGURATION, 0x8E, # 0b10001110, # 11, a[0]=0 Select external Vcc supply, a[0]=1 Reserved(reset)
    self.C_OLED_SET_POWER_SAVE_MODE, 0x00, # 13, 0-no power save, 0x1A-power save
    self.C_OLED_SET_PHASE_1_AND_2_PERIOD_ADJUSTMENT, 0x74, # 15
    self.C_OLED_SET_DISPLAY_CLOCK_DIVIDER, 0xF0, # 17
    self.C_OLED_SET_PRECHARGE_A, 0x64, # 19
    self.C_OLED_SET_PRECHARGE_B, 0x78, # 21
    self.C_OLED_SET_PRECHARGE_C, 0x64, # 23
    self.C_OLED_SET_PRECHARGE_LEVEL, 0x31, # 25
    self.C_OLED_SET_CONTRAST_COLOR_A, 0xFF, # 27, 255
    self.C_OLED_SET_CONTRAST_COLOR_B, 0xFF, # 29, 255
    self.C_OLED_SET_CONTRAST_COLOR_C, 0xFF, # 31, 255
    self.C_OLED_SET_VCOMH, 0x3E,
    self.C_OLED_SET_MASTER_CURRENT_CONTROL, 0x06,
    self.C_OLED_SET_COLUMN_ADDRESS, 0x00, 0x5F, # 33, 96
    self.C_OLED_SET_ROW_ADDRESS, 0x00, 0x3F, # 36, 63
    self.C_OLED_SET_DISPLAY_ON, # 39
    self.C_OLED_NOP1, # 40 -- during debugging sent as data
    ]) # end bytearray


#void dc(uint8_t state)
#{
#  if(state)
#    *simple_out |= (1<<11);
#  else
#    *simple_out &= ~(1<<11);
#}


#void resn(uint8_t state)
#{
#  if(state)
#    *simple_out |= (1<<10);
#  else
#    *simple_out &= ~(1<<10);
#}


  def oled_fill_screen(self, color):
    self.dc.value(0) # command
    self.oled_spi.write(bytearray([self.C_OLED_SET_COLUMN_ADDRESS,
    0,
    0x5F,
    self.C_OLED_SET_ROW_ADDRESS,
    0,
    0x3F]))
    self.dc.value(1) # data
    for i in range(6144):
      self.oled_spi.write(bytearray([color]))

  def oled_init(self):
    print("init")
    self.csn.value(0) # enable OLED
    self.dc.value(0) # commands
    self.resn.value(0)
    sleep_ms(5)
    self.resn.value(1)
    sleep_ms(20)
    self.oled_spi.write(self.oled_init_sequence)
    self.oled_fill_screen(0x42)

#void oled_horizontal_line(uint8_t y, uint8_t color)
#{
#  dc(0); # command
#  spi_rxtx(oled_spi, self.C_OLED_SET_ROW_ADDRESS);
#  spi_rxtx(oled_spi, y);
#  spi_rxtx(oled_spi, y);
#  dc(1); # data
#  for(int i = 0; i < 96; i++)
#    spi_rxtx(oled_spi, color);
#}

#uint8_t oled_color_stripes()
#{
#  oled_horizontal_line((oled_y+ 0) & 63, 0xFF); # white
#  oled_horizontal_line((oled_y+16) & 63, 0x03); # blue
#  oled_horizontal_line((oled_y+32) & 63, 0x1C); # green
#  oled_horizontal_line((oled_y+48) & 63, 0xE0); # red
#  return oled_y++ & 63;
#}


# set up variables using the SD utility library functions:
#void oled_read(char *a)
#{
#  uint8_t line = oled_color_stripes();
#  sprintf(a, "OLED: %02x", line);
#}

oled().oled_init()
