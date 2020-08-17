# Micropython ESP32 and ST7789 with polyline accelerator core

# vector font which looks good as 5x7 or scaled
# polyline buffer can hold 512 points.
# it should fit average content of one screen line of 40 chars 
# most complex char is "8", buffer can hold 31 of them and ending symbol

from time import sleep_ms
from machine import SPI,Pin
from micropython import const
from uctypes import addressof

class vectorfont:
  def __init__(self,csn,busy,spi):
    self.csn=csn # Pin.OZT
    self.busy=busy # Pin.IN
    self.spi=spi # SPI st7789, self.spi.write(bytearray([...]))
    # SPI commands
    self.load_poly=bytearray([0, 0x1C,0xDD,0x00,0x00]) # loade buffer, follows: XMSB,XLSB,YMSB,YLSB
    self.color_draw=bytearray([0, 0x1C,0xDE,0x00,0x00, 0,0]) # draw buffer, last 2 bytes = color MSB,LSB 
    self.end_poly=bytearray([0x80,0x00,0x00,0x00, 0x00,0x00,0x80,0x00]) # HACK off-screen draw one pixel
    # screen dimension (0,0) is top left origin
    # (width-1,height-1) is bottom right origin
    self.width=240
    self.height=320
    # vector font as associative array of polylines, delimited by 128,any
    self.font = {
      " ":bytearray([]),
      ".":bytearray([2,5, 2,6]),
      "!":bytearray([2,0, 2,4, 128,128, 2,6, 2,6]),
      "?":bytearray([0,1, 1,0, 3,0, 4,1, 4,2, 2,3, 2,4, 128,128, 2,6, 2,6]),
      "|":bytearray([2,0, 2,6]),
      "#":bytearray([0,2, 4,2, 128,128, 0,4, 4,4, 128,128, 1,1, 1,5, 128,128, 3,1, 3,5]),
      "$":bytearray([4,1, 1,1, 0,2, 1,3, 3,3, 4,4, 3,5, 0,5, 128,128, 2,0, 2,6]),
      "%":bytearray([4,1, 0,5, 128,128, 1,0, 0,1, 1,2, 2,1, 1,0, 128,128,  3,4, 2,5, 3,6, 4,5, 3,4]),
      "&":bytearray([4,4, 2,6, 1,6, 0,5, 0,4, 3,1, 2,0, 1,0, 0,1, 0,2, 4,6]),
      ",":bytearray([2,5, 2,6, 1,7]),
      ":":bytearray([2,0, 2,1, 128,128, 2,5, 2,6]),
      ";":bytearray([2,0, 2,1, 128,128, 2,5, 2,6, 1,7]),
      "+":bytearray([0,3, 4,3, 128,128, 2,1, 2,5]),
      "-":bytearray([0,3, 4,3]),
      "*":bytearray([0,2, 1,3, 3,3, 4,4, 128,128, 0,4, 1,3, 3,3, 4,2, 128,128, 2,1, 2,5]),
      "/":bytearray([4,1, 0,5]),
      "\\":bytearray([0,1, 4,5]),
      "=":bytearray([0,2, 4,2, 128,128, 0,4, 4,4]),
      "(":bytearray([3,0, 2,1, 2,5, 3,6]),
      ")":bytearray([1,0, 2,1, 2,5, 1,6]),
      "[":bytearray([3,0, 2,0, 2,6, 3,6]),
      "]":bytearray([1,0, 2,0, 2,6, 1,6]),
      "{":bytearray([4,0, 3,0, 2,1, 2,2, 1,3, 2,4, 2,5, 3,6, 4,6, 128,128, 0,3, 1,3]),
      "}":bytearray([0,0, 1,0, 2,1, 2,2, 3,3, 2,4, 2,5, 1,6, 0,6, 128,128, 3,3, 4,3]),
      "_":bytearray([0,6, 4,6]),
      "'":bytearray([2,0, 2,2]),
      '"':bytearray([1,0, 1,2, 128,128, 3,0, 3,2]),
      "^":bytearray([1,1, 2,0, 3,1]),
      "~":bytearray([0,3, 1,2, 2,3, 3,2]),
      "°":bytearray([1,0, 1,3, 3,3, 3,0, 1,0]),
      "0":bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5, 4,1, 0,5]),
      "1":bytearray([1,1, 2,0, 2,6, 128,128, 1,6, 3,6]),
      "2":bytearray([0,1, 1,0, 3,0, 4,1, 4,2, 0,6, 4,6]),
      "3":bytearray([0,1, 1,0, 3,0, 4,1, 4,2, 3,3, 4,4, 4,5, 3,6, 1,6, 0,5, 128,128, 1,3, 3,3]),
      "4":bytearray([3,6, 3,0, 0,3, 0,4, 4,4]),
      "5":bytearray([4,0, 0,0, 0,3, 1,2, 3,2, 4,3, 4,5, 3,6, 1,6, 0,5]),
      "6":bytearray([3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5, 4,4, 3,3, 0,3]),
      "7":bytearray([0,1, 0,0, 4,0, 4,2, 1,5, 1,6]),
      "8":bytearray([3,3, 4,2, 4,1, 3,0, 1,0, 0,1, 0,2, 1,3, 3,3, 4,4, 4,5, 3,6, 1,6, 0,5, 0,4, 1,3]),
      "9":bytearray([1,6, 3,6, 4,5, 4,1, 3,0, 1,0, 0,1, 0,2, 1,3, 4,3]),
      "@":bytearray([3,6, 1,6, 0,5, 0,1, 1,0, 3,0, 4,1, 4,4, 2,4, 2,2, 4,2]),
      "A":bytearray([0,6, 0,2, 2,0, 4,2, 4,6, 128,128, 0,4, 4,4]),
      "B":bytearray([3,3, 4,2, 4,1, 3,0, 0,0, 0,6, 3,6, 4,5, 4,4, 3,3, 0,3]),
      "C":bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5]),
      "D":bytearray([0,0, 0,6, 3,6, 4,5, 4,1, 3,0, 0,0]),
      "E":bytearray([4,0, 0,0, 0,6, 4,6, 128,128, 0,3, 3,3]),
      "F":bytearray([4,0, 0,0, 0,6, 128,128, 0,3, 3,3]),
      "G":bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5, 4,3, 2,3]),
      "H":bytearray([0,0, 0,6, 128,128, 4,0, 4,6, 128,128, 0,3, 4,3]),
      "I":bytearray([2,0, 2,6, 128,128, 1,0, 3,0, 128,128, 1,6, 3,6]),
      "J":bytearray([0,5, 1,6, 3,6, 4,5, 4,0]),
      "K":bytearray([0,0, 0,6, 128,128, 4,0, 1,3, 0,3, 128,128, 4,6, 1,3]),
      "L":bytearray([0,0, 0,6, 4,6]),
      "M":bytearray([0,6, 0,0, 2,2, 4,0, 4,6]),
      "N":bytearray([0,6, 0,0, 4,4, 128,128, 4,0, 4,6]),
      "O":bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5, 4,1]),
      "P":bytearray([0,6, 0,0, 3,0, 4,1, 4,2, 3,3, 0,3]),
      "Q":bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 2,6, 4,3, 4,1, 128,128, 2,4, 4,6]),
      "R":bytearray([0,6, 0,0, 3,0, 4,1, 4,2, 3,3, 0,3, 128,128, 1,3, 4,6]),
      "S":bytearray([4,1, 3,0, 1,0, 0,1, 0,2, 1,3, 3,3, 4,4, 4,5, 3,6, 1,6, 0,5]),
      "T":bytearray([2,0, 2,6, 128,128, 0,0, 4,0]),
      "U":bytearray([0,0, 0,5, 1,6, 3,6, 4,5, 4,0]),
      "V":bytearray([0,0, 0,4, 2,6, 4,4, 4,0]),
      "W":bytearray([0,0, 0,6, 2,4, 4,6, 4,0]),
      "X":bytearray([0,0, 0,1, 4,5, 4,6, 128,128, 0,6, 0,5, 4,1, 4,0]),
      "Y":bytearray([0,0, 0,1, 2,3, 2,6, 128,128, 4,0, 4,1, 2,3]),
      "Z":bytearray([0,0, 4,0, 4,1, 0,5, 0,6, 4,6]),
      "Č":bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5, 128,128, 1,-2, 2,-1, 3,-2]),
      "Ć":bytearray([4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 3,6, 4,5, 128,128, 2,-1, 3,-2]),
      "Đ":bytearray([0,0, 0,6, 3,6, 4,5, 4,1, 3,0, 0,0, 128,128, -1,3, 1,3]),
      "Š":bytearray([4,1, 3,0, 1,0, 0,1, 0,2, 1,3, 3,3, 4,4, 4,5, 3,6, 1,6, 0,5, 128,128, 1,-2, 2,-1, 3,-2]),
      "Ž":bytearray([0,0, 4,0, 4,1, 0,5, 0,6, 4,6, 128,128, 1,-2, 2,-1, 3,-2]),
      "a":bytearray([1,2, 3,2, 4,3, 4,6, 1,6, 0,5, 1,4, 4,4]),
      "b":bytearray([0,0, 0,6, 3,6, 4,5, 4,3, 3,2, 2,2, 0,4]),
      "c":bytearray([4,2, 1,2, 0,3, 0,5, 1,6, 4,6]),
      "d":bytearray([4,0, 4,6, 1,6, 0,5, 0,3, 1,2, 2,2, 4,3]),
      "e":bytearray([0,4, 4,4, 4,3, 3,2, 1,2, 0,3, 0,5, 1,6, 3,6]),
      "f":bytearray([4,1, 3,0, 2,0, 1,1, 1,6, 128,128, 0,3, 2,3]),
      "g":bytearray([1,6, 3,6, 4,5, 4,2, 1,2, 0,3, 1,4, 4,4]),
      "h":bytearray([0,0, 0,6, 128,128, 4,6, 4,3, 3,2, 2,2, 0,4]),
      "i":bytearray([1,2, 2,2, 2,6, 128,128, 1,6, 3,6, 128,128, 2,0, 2,0]),
      "j":bytearray([1,2, 2,2, 2,6, 1,7, 128,128, 2,0, 2,0]),
      "k":bytearray([0,0, 0,6, 128,128, 4,2, 2,4, 4,6, 128,128, 0,4, 2,4]),
      "l":bytearray([1,0, 2,0, 2,6, 128,128, 1,6, 3,6]),
      "m":bytearray([0,6, 0,2, 3,2, 4,3, 4,6, 128,128, 2,2, 2,6]),
      "n":bytearray([0,6, 0,2, 3,2, 4,3, 4,6]),
      "o":bytearray([4,3, 3,2, 1,2, 0,3, 0,5, 1,6, 3,6, 4,5, 4,3]),
      "p":bytearray([0,7, 0,2, 3,2, 4,3, 4,4, 3,5, 0,5]),
      "q":bytearray([4,7, 4,2, 1,2, 0,3, 0,4, 1,5, 4,5]),
      "r":bytearray([0,6, 0,2, 128,128, 0,4, 2,2, 4,2]),
      "s":bytearray([4,2, 1,2, 0,3, 1,4, 3,4, 4,5, 3,6, 0,6]),
      "t":bytearray([2,0, 2,5, 3,6, 4,6, 128,128, 1,2, 3,2]),
      "u":bytearray([0,2, 0,5, 1,6, 4,6, 4,2]),
      "v":bytearray([0,2, 0,4, 2,6, 4,4, 4,2]),
      "w":bytearray([0,2, 0,5, 1,6, 4,6, 4,2, 128,128, 2,2, 2,6]),
      "x":bytearray([0,2, 4,6, 128,128, 0,6, 4,2]),
      "y":bytearray([0,2, 0,4, 1,5, 4,5, 128,128, 4,2, 4,6, 3,7, 1,7]),
      "z":bytearray([0,2, 4,2, 0,6, 4,6]),
      "č":bytearray([4,2, 1,2, 0,3, 0,5, 1,6, 4,6, 128,128, 1,0, 2,1, 3,0]),
      "ć":bytearray([4,2, 1,2, 0,3, 0,5, 1,6, 4,6, 128,128, 2,1, 3,0]),
      "đ":bytearray([4,0, 4,6, 1,6, 0,5, 0,3, 1,2, 2,2, 4,3, 128,128, 3,1, 5,1]),
      "š":bytearray([4,2, 1,2, 0,3, 1,4, 3,4, 4,5, 3,6, 0,6, 128,128, 1,0, 2,1, 3,0]),
      "ž":bytearray([0,2, 4,2, 0,6, 4,6, 128,128, 1,0, 2,1, 3,0]),
    }

  # convert glyph polyline to hardware coordinates and load them to polyline buffer
  # x,y  = offset
  # xscale, yscale = 256 default for 5x7 font
  # line = bytearray([x0,y0, x1,y1, ... xn,yn]); 128,any=delimiter
  @micropython.viper
  def glyph2poly(self, x:int, y:int, xscale:int, yscale:int, line):
    if x >= int(self.width) or y >= int(self.height):
      return
    p = ptr8(addressof(line))
    #p = memoryview(line)
    n = 32768 # 1<<15 starts new polyline
    m = int(len(line))>>1
    for i in range(m):
      xp = p[2*i]
      if xp > 128: # negative
        xp = xp-256 # signed
      yp = p[1+2*i]
      if yp > 128: # negative
        yp = yp-256 # signed
      if xp == 128: # discontinue polyline
        n = 32768 # start new polyline
      else:
        x0 = (((xp*xscale)>>8)+x)|n
        y0 = ((yp*yscale)>>8)+y
        self.spi.write(bytearray([x0>>8,x0, y0>>8,y0]))
        n = 0

  # draw polyline loaded in the buffer
  @micropython.viper
  def draw_poly(self, color:int):
    c8 = ptr8(addressof(self.color_draw))
    c8[5]=color>>8
    c8[6]=color
    self.csn.off()
    self.spi.write(self.color_draw)
    self.csn.on()

  # x,y = coordinate upper left corner of the first char
  # xscale, yscale = 256 for default size, 128 for half size, 512 for double size
  # text = string
  # color = bytearray([r,g,b])
  # spacing = between chars
  def text(self, text, x=0, y=0, color=0xFFFF, spacing=6, xscale=256, yscale=256):
    y += 80 # FIXME only for 180 deg hardware screen rotation
    while self.busy.value():
      continue
    self.csn.off()
    self.spi.write(self.load_poly)
    for char in text:
      self.glyph2poly(x,y,xscale,yscale,self.font[char])
      x += spacing
    self.spi.write(self.end_poly)
    self.csn.on()
    self.draw_poly(color)
