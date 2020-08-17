# Micropython ESP32 and passthru bitstream

from time import sleep_ms
from machine import SPI,Pin
from micropython import const
from uctypes import addressof

class vectorfont:
  def __init__(self,width,height,line):
    # line drawing function takes one parameter
    # bytearray([x0,y0,x1,y1,r,g,b])
    self.line=line
    # screen dimension (0,0) is top left origin
    # (width-1,height-1) is bottom right origin
    self.width=width
    self.height=height
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

  # x,y  = offset
  # xscale, yscale = 256 default for 5x7 font
  # line = bytearray([x0,y0, x1,y1, ... xn,yn]); 128,any=delimiter
  # buf  = bytearray([x0,y0, x1,y1, color[0],color[1],color[2]])
  @micropython.viper
  def polyline(self, x:int, y:int, xscale:int, yscale:int, line, buf):
    if x >= int(self.width) or y >= int(self.height):
      return
    p = ptr8(addressof(line))
    b = ptr8(addressof(buf))
    n = 0
    for i in range(int(len(line))>>1):
      xp = p[2*i]
      if xp == 128: # discontinue polyline
        n = 0 # start new polyline
      else:
        b[  2*(i&1)] = ((     xp *xscale)>>8)+x
        b[1+2*(i&1)] = ((p[1+2*i]*yscale)>>8)+y
        if n:
          self.line(buf)
        else:
          n = 1

  # x,y = coordinate upper left corner of the first char
  # xscale, yscale = 256 for default size, 128 for half size, 512 for double size
  # text = string
  # color = bytearray([r,g,b])
  # spacing = between chars
  def text(self, text, x=0, y=0, color=b"\xFF\xFF\xFF", spacing=6, xscale=256, yscale=256):
    buf = bytearray([0,0,0,0,color[0],color[1],color[2]])
    x0 = x
    for char in text:
      self.polyline(x0,y,xscale,yscale,self.font[char],buf)
      x0 += spacing
