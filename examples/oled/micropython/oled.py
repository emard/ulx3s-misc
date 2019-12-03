# Micropython ESP32 and passthru bitstream

from time import sleep_ms
from machine import SPI,Pin
from micropython import const
from uctypes import addressof
import framebuf

class oled:

  def init_pinout_oled(self):
    self.gpio_csn = const(17)
    self.gpio_resn = const(26)
    self.gpio_dc = const(16)
    self.gpio_sck = const(14)
    self.gpio_mosi = const(15)
    self.gpio_miso = const(2)

  def init_bitbang(self):
    self.dc=Pin(self.gpio_dc,Pin.OUT)
    self.resn=Pin(self.gpio_resn,Pin.OUT)
    self.csn=Pin(self.gpio_csn,Pin.OUT)

  def init_spi(self):
    self.oled_spi=SPI(self.spi_channel, baudrate=self.spi_freq, polarity=0, phase=0, bits=8, firstbit=SPI.MSB, sck=Pin(self.gpio_sck), mosi=Pin(self.gpio_mosi), miso=Pin(self.gpio_miso))

  def oled_ssd1331_commands(self):
    self.C_OLED_NOP1 = const(0xBC)
    self.C_OLED_NOP2 = const(0xBD) # delay nop
    self.C_OLED_NOP3 = const(0xE3)
    self.C_OLED_SET_DISPLAY_OFF = const(0xAE) # 0b10101110
    self.C_OLED_SET_REMAP_COLOR = const(0xA0)
    self.C_OLED_ULX3S_REMAP = const(0x60) # 0b01100000 # A[6]=0:RGB332, A[6]=1:RGB565; A[0]=0:left-to-right, A[1]=1:right-to-left
    self.C_OLED_SET_DISPLAY_START_LINE = const(0xA1)
    self.C_OLED_SET_DISPLAY_OFFSET = const(0xA1)
    self.C_OLED_SET_DISPLAY_MODE_NORMAL = const(0xA4)
    self.C_OLED_SET_MULTIPLEX_RATIO = const(0xA8)
    self.C_OLED_SET_MASTER_CONFIGURATION = const(0xAD)
    self.C_OLED_SET_POWER_SAVE_MODE = const(0xB0)
    self.C_OLED_SET_PHASE_1_AND_2_PERIOD_ADJUSTMENT = const(0xB1)
    self.C_OLED_SET_DISPLAY_CLOCK_DIVIDER = const(0xF0)
    self.C_OLED_SET_PRECHARGE_A = const(0x8A)
    self.C_OLED_SET_PRECHARGE_B = const(0x8B)
    self.C_OLED_SET_PRECHARGE_C = const(0x8C)
    self.C_OLED_SET_PRECHARGE_LEVEL = const(0xBB)
    self.C_OLED_SET_VCOMH = const(0xBE)
    self.C_OLED_SET_MASTER_CURRENT_CONTROL = const(0x87)
    self.C_OLED_SET_CONTRAST_COLOR_A = const(0x81)
    self.C_OLED_SET_CONTRAST_COLOR_B = const(0x82)
    self.C_OLED_SET_CONTRAST_COLOR_C = const(0x83)
    self.C_OLED_SET_COLUMN_ADDRESS = const(0x15)
    self.C_OLED_SET_ROW_ADDRESS = const(0x75)
    self.C_OLED_SET_DISPLAY_ON = const(0xAF)
    self.C_OLED_DRAW_LINE = const(0x21) # x0,y0,x1,y1,color_c,color_b,color_a
    self.C_OLED_DRAW_RECTANGLE = const(0x22) # x0,y0,x1,y1,outline_c,outline_b,outline_a,fill_c,fill_b,fill_a
    self.C_OLED_FILL_ENABLE = const(0x26) # a[0]=1 enable rectangle fill, a[4]=1 enable reverse copy
    self.C_OLED_COPY = const(0x23) # x0,y0,x1,y1,x2,y2 copy 0-1 to 2
    self.C_OLED_CLEAR_WINDOW = const(0x25) # x0,y0,x1,y1

    self.oled_init_sequence = bytearray([
      self.C_OLED_NOP1, # 0, 10111100
      self.C_OLED_SET_DISPLAY_OFF, # 1, 0b10101110
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

  def __init__(self):
    self.spi_channel = const(1) # -1 soft, 1:sd, 2:jtag
    self.spi_freq = const(6600000) # Hz SPI frequency (150 ns datasheet p.57)
    self.oled_ssd1331_commands()
    self.init_pinout_oled()
    self.init_spi()
    self.init_bitbang()
    self.init_font()
    self.width = const(96)
    self.height = const(64)
    self.fb = framebuf.FrameBuffer(bytearray(self.width * self.height * 2), self.width, self.height, framebuf.RGB565)

  def fb_show(self):
    self.dc.value(0) # command
    self.oled_spi.write(bytearray([
      self.C_OLED_SET_COLUMN_ADDRESS, 0, self.width-1, # 96
      self.C_OLED_SET_ROW_ADDRESS,    0, self.height-1, # 64
    ]))
    self.dc.value(1) # data
    self.oled_spi.write(self.fb)

  def oled_init(self):
    self.csn.value(0) # enable OLED
    self.dc.value(0) # commands
    self.resn.value(0)
    sleep_ms(5)
    self.resn.value(1)
    sleep_ms(20)
    self.oled_spi.write(self.oled_init_sequence)
    self.box([0,0,self.width-1,self.height-1],[0,64,128],[0,64,128])

  def oled_horizontal_line(self, y, color):
    self.line([0,y,self.width-1,y],color)

  # line = bytearray([x0,y0,x1,y1])
  # color = bytearray([r,g,b])
  def line(self, line, color):
    self.dc.value(0) # command
    self.oled_spi.write(bytearray([self.C_OLED_DRAW_LINE]) + bytearray(line) + bytearray(color))

  def scroll_up(self, n):
    self.dc.value(0) # command
    self.oled_spi.write(bytearray([self.C_OLED_COPY]) + bytearray([0,n, self.width-1, self.height-1, 0,0]))

  # x,y  = offset
  # width, height = 6,8 default for 5x7 font
  # line = bytearray([x0,y0, x1,y1, ... xn,yn])
  # buf  = bytearray([self.C_OLED_DRAW_LINE,0,0,0,0,color[0],color[1],color[2]])
  @micropython.viper
  def polyline_fast(self, x:int, y:int, width:int, height:int, line, buf):
    p = ptr8(addressof(line))
    b = ptr8(addressof(buf))
    b[3] = p[0]* width//6+x
    b[4] = p[1]*height//8+y
    for i in range(int(len(line))//2-1):
      b[1+2*(i&1)] = p[2+2*i]* width//6+x
      b[2+2*(i&1)] = p[3+2*i]*height//8+y
      self.oled_spi.write(buf)

  # x,y = coordinate upper left corner of the first char
  # text = string
  # color = bytearray([r,g,b])
  # spacing = between chars
  def text(self, text, x=0, y=0, color=b"\xFF\xFF\xFF", spacing=6, width=6, height=8):
    self.dc.value(0) # command
    buf = bytearray([self.C_OLED_DRAW_LINE,0,0,0,0,color[0],color[1],color[2]])
    x0 = x
    for char in text:
      for line in self.font[char]:
        self.polyline_fast(x0,y,width,height,line,buf)
      x0 += spacing

  # vector font as associative array of polylines
  def init_font(self):
    self.font = {
      " ":[],
      ".":[bytearray([2,5, 2,6])],
      ",":[bytearray([2,5, 2,6, 1,7])],
      ":":[bytearray([2,0, 2,1]), bytearray([2,5, 2,6])],
      ";":[bytearray([2,0, 2,1]), bytearray([2,5, 2,6, 1,7])],
      "+":[bytearray([0,3, 4,3]), bytearray([2,1, 2,5])],
      "-":[bytearray([0,3, 4,3])],
      "*":[bytearray([0,2, 1,3, 3,3, 4,4]), bytearray([0,4, 1,3, 3,3, 4,2]), bytearray([2,1, 2,5])],
      "/":[bytearray([4,1, 0,5])],
      "=":[bytearray([0,2, 4,2]), bytearray([0,4, 4,4])],
      "(":[bytearray([3,0, 2,1, 2,5, 3,6])],
      ")":[bytearray([1,0, 2,1, 2,5, 1,6])],
      "[":[bytearray([3,0, 2,0, 2,6, 3,6])],
      "]":[bytearray([1,0, 2,0, 2,6, 1,6])],
      "{":[bytearray([4,0, 3,0, 2,1, 2,2, 1,3, 2,4, 2,5, 3,6, 4,6]), bytearray([0,3, 1,3])],
      "}":[bytearray([0,0, 1,0, 2,1, 2,2, 3,3, 2,4, 2,5, 1,6, 0,6]), bytearray([3,3, 4,3])],
      "_":[bytearray([0,6, 4,6])],
      "'":[bytearray([2,0, 2,2])],
      '"':[bytearray([1,0, 1,2]), bytearray([3,0, 3,2])],
      "°":[bytearray([1,0, 1,3, 3,3, 3,0, 1,0])],
      "0":[bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5, 4,1, 0,5])],
      "1":[bytearray([1,1, 2,0, 2,6]), bytearray([1,6, 3,6])],
      "2":[bytearray([0,1, 1,0, 3,0, 4,1, 4,2, 0,6, 4,6])],
      "3":[bytearray([0,1, 1,0, 3,0, 4,1, 4,2, 3,3, 4,4, 4,5, 3,6, 1,6, 0,5]), bytearray([1,3, 3,3])],
      "4":[bytearray([3,6, 3,0, 0,3, 0,4, 4,4])],
      "5":[bytearray([4,0, 0,0, 0,3, 1,2, 3,2, 4,3, 4,5, 3,6, 1,6, 0,5])],
      "6":[bytearray([4,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5, 4,3, 3,2, 0,2])],
      "7":[bytearray([0,1, 0,0, 4,0, 4,2, 1,5, 1,6])],
      "8":[bytearray([1,3, 0,2, 0,1, 1,0, 3,0, 4,1, 4,2, 3,3, 4,4, 4,5, 3,6, 1,6, 0,5, 0,4, 1,3]), bytearray([1,3, 3,3])],
      "9":[bytearray([0,6, 3,6, 4,5, 4,1, 3,0, 1,0, 0,1, 0,2, 1,3, 4,3])],
      "@":[bytearray([3,6, 1,6, 0,5, 0,1, 1,0, 3,0, 4,1, 4,4, 2,4, 2,2, 4,2])],
      "A":[bytearray([0,6, 0,2, 2,0, 4,2, 4,6]), bytearray([0,4, 4,4])],
      "B":[bytearray([3,3, 4,2, 4,1, 3,0, 0,0, 0,6, 3,6, 4,5, 4,4, 3,3, 0,3])],
      "C":[bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5])],
      "D":[bytearray([0,0, 0,6, 3,6, 4,5, 4,1, 3,0, 0,0])],
      "E":[bytearray([4,0, 0,0, 0,6, 4,6]), bytearray([0,3, 3,3])],
      "F":[bytearray([4,0, 0,0, 0,6]), bytearray([0,3, 3,3])],
      "G":[bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5, 4,3, 2,3])],
      "H":[bytearray([0,0, 0,6]), bytearray([4,0, 4,6]), bytearray([0,3, 4,3])],
      "I":[bytearray([2,0, 2,6]), bytearray([1,0, 3,0]), bytearray([1,6, 3,6])],
      "J":[bytearray([0,5, 1,6, 3,6, 4,5, 4,0])],
      "K":[bytearray([0,0, 0,6]), bytearray([4,0, 1,3, 0,3]), bytearray([4,6, 1,3])],
      "L":[bytearray([0,0, 0,6, 4,6])],
      "M":[bytearray([0,6, 0,0, 2,2, 4,0, 4,6])],
      "N":[bytearray([0,6, 0,0, 4,4]), bytearray([4,0, 4,6])],
      "O":[bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5, 4,1])],
      "P":[bytearray([0,6, 0,0, 3,0, 4,1, 4,2, 3,3, 0,3])],
      "Q":[bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 2,6, 4,3, 4,1]), bytearray([2,4, 4,6])],
      "R":[bytearray([0,6, 0,0, 3,0, 4,1, 4,2, 3,3, 0,3]), bytearray([1,3, 4,6])],
      "S":[bytearray([4,1, 3,0, 1,0, 0,1, 0,2, 1,3, 3,3, 4,4, 4,5, 3,6, 1,6, 0,5])],
      "T":[bytearray([2,0, 2,6]), bytearray([0,0, 4,0])],
      "U":[bytearray([0,0, 0,5, 1,6, 3,6, 4,5, 4,0])],
      "V":[bytearray([0,0, 0,4, 2,6, 4,4, 4,0])],
      "W":[bytearray([0,0, 0,6, 2,4, 4,6, 4,0])],
      "X":[bytearray([0,0, 0,1, 4,5, 4,6]), bytearray([0,6, 0,5, 4,1, 4,0])],
      "Y":[bytearray([0,0, 0,1, 2,3, 2,6]), bytearray([4,0, 4,1, 2,3])],
      "Z":[bytearray([0,0, 4,0, 4,1, 0,5, 0,6, 4,6])],
      "Č":[bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5]), bytearray([1,-2, 2,-1, 3,-2])],
      "Ć":[bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5]), bytearray([2,-1, 3,-2])],
      "Đ":[bytearray([0,0, 0,6, 3,6, 4,5, 4,1, 3,0, 0,0]), bytearray([-1,3, 1,3])],
      "Š":[bytearray([4,1, 3,0, 1,0, 0,1, 0,2, 1,3, 3,3, 4,4, 4,5, 3,6, 1,6, 0,5]), bytearray([1,-2, 2,-1, 3,-2])],
      "Ž":[bytearray([0,0, 4,0, 4,1, 0,5, 0,6, 4,6]), bytearray([1,-2, 2,-1, 3,-2])],
      "a":[bytearray([1,2, 3,2, 4,3, 4,6, 1,6, 0,5, 1,4, 4,4])],
      "b":[bytearray([0,0, 0,6, 3,6, 4,5, 4,3, 3,2, 2,2, 0,4])],
      "c":[bytearray([3,2, 1,2, 0,3, 0,5, 1,6, 3,6, 4,5])],
      "d":[bytearray([4,0, 4,6, 1,6, 0,5, 0,3, 1,2, 2,2, 4,3])],
      "e":[bytearray([0,4, 4,4, 4,3, 3,2, 1,2, 0,3, 0,5, 1,6, 3,6])],
      "f":[bytearray([4,1, 3,0, 2,0, 1,1, 1,6]), bytearray([0,3, 2,3])],
      "x":[bytearray([0,2, 4,6]), bytearray([0,6, 4,2])],
    }

  # line = bytearray([x0,y0,x1,y1])
  # outline,inside = bytearray([r,g,b])
  def box(self, box, outline, inside):
    self.dc.value(0) # command
    self.oled_spi.write(bytearray([self.C_OLED_FILL_ENABLE, 1]))
    self.oled_spi.write(bytearray([self.C_OLED_DRAW_RECTANGLE]) + bytearray(box) + bytearray(outline) + bytearray(inside))

  # fills box with 0 (black)
  def box_black(self, box):
    self.dc.value(0) # command
    self.oled_spi.write(bytearray([self.C_OLED_CLEAR_WINDOW]) + bytearray(box))

  def oled_color_stripes(self, y):
    y = y & 63
    self.oled_horizontal_line((y+ 0) & 63, [255,255,255]) # white
    self.oled_horizontal_line((y+16) & 63, [  0,  0,255]) # blue
    self.oled_horizontal_line((y+32) & 63, [  0,255,  0]) # green
    self.oled_horizontal_line((y+48) & 63, [255,  0,  0]) # red

  def oled_run_stripes(self, n):
    for i in range(n):
      self.oled_color_stripes(i)
      sleep_ms(5)

disp = oled()
disp.oled_init()
print("4 horizontal stripes (RGBW) scrolling down")
disp.oled_run_stripes(128)
# scroll some text
black = bytearray([0,0,0])
white = bytearray([255,255,255])
yellow = bytearray([255,255,0])
print("scroll line 0..99")
for i in range(100):
  disp.scroll_up(8)
  sleep_ms(1) # wait for scroll to finish
  disp.box_black(bytearray([0,56,95,63])) # text background
  disp.text("SCROLL %d" % i,0,56,white) # text foreground
print("print('MicroPython!'), raster font 8x8, underlined")
disp.fb.fill(0)
disp.fb.text('MicroPython!', 0, 0, 0xffff)
disp.fb.hline(0, 10, 96, 0xffff)
disp.fb_show()
print("blue box with red outline")
disp.box(bytearray([0,30,95,63]),bytearray([170,0,0]),bytearray([0,0,170]))
print("print('1234 ABC'), vector font 12x16")
disp.text("1234 ABC",1,32,white,12,12,16)
print("print('ČĆĐŠŽ'), vector font 6x8")
disp.text("'Č'.Ć,Đ:Š;\"Ž\"",0,16,yellow)
del disp
