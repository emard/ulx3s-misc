# bresenham line algorithm
from uctypes import addressof

# Display resolution
EPD_WIDTH       = const(200)
EPD_HEIGHT      = const(200)

class line_bresenham:
  def __init__(self):
    return

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
