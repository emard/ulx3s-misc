from time import sleep_ms
from micropython import const
import ustruct as struct
from uctypes import addressof

# commands
ST77XX_NOP = const(0x00)
ST77XX_SWRESET = const(0x01)
ST77XX_RDDID = const(0x04)
ST77XX_RDDST = const(0x09)

ST77XX_SLPIN = const(0x10)
ST77XX_SLPOUT = const(0x11)
ST77XX_PTLON = const(0x12)
ST77XX_NORON = const(0x13)

ST77XX_INVOFF = const(0x20)
ST77XX_INVON = const(0x21)
ST77XX_DISPOFF = const(0x28)
ST77XX_DISPON = const(0x29)
ST77XX_CASET = const(0x2A)
ST77XX_RASET = const(0x2B)
ST77XX_RAMWR = const(0x2C)
ST77XX_RAMRD = const(0x2E)

ST77XX_PTLAR = const(0x30)
ST77XX_COLMOD = const(0x3A)
ST7789_MADCTL = const(0x36)

ST7789_MADCTL_MY = const(0x80)
ST7789_MADCTL_MX = const(0x40)
ST7789_MADCTL_MV = const(0x20)
ST7789_MADCTL_ML = const(0x10)
ST7789_MADCTL_BGR = const(0x08)
ST7789_MADCTL_MH = const(0x04)
ST7789_MADCTL_RGB = const(0x00)

ST7789_RDID1 = const(0xDA)
ST7789_RDID2 = const(0xDB)
ST7789_RDID3 = const(0xDC)
ST7789_RDID4 = const(0xDD)

ColorMode_65K = const(0x50)
ColorMode_262K = const(0x60)
ColorMode_12bit = const(0x03)
ColorMode_16bit = const(0x05)
ColorMode_18bit = const(0x06)
ColorMode_16M = const(0x07)

# Color definitions
BLACK = const(0x0000)
BLUE = const(0x001F)
RED = const(0xF800)
GREEN = const(0x07E0)
CYAN = const(0x07FF)
MAGENTA = const(0xF81F)
YELLOW = const(0xFFE0)
WHITE = const(0xFFFF)

_BUFFER_SIZE = const(256)

@micropython.viper
def color565(r:int, g:int, b:int) -> int:
    """Convert red, green and blue values (0-255) into a 16-bit 565 encoding."""
    return (r & 0xf8) << 8 | (g & 0xfc) << 3 | b >> 3

class ST77xx:
    def __init__(self, spi, width, height, reset, dc, cs=None, backlight=None,
                 xstart=-1, ystart=-1):
        """
        display = st7789.ST7789(
            SPI(1, baudrate=40000000, phase=0, polarity=1),
            240, 240,
            reset=machine.Pin(5, machine.Pin.OUT),
            dc=machine.Pin(2, machine.Pin.OUT),
        )

        """
        self.width = width
        self.height = height
        self.spi = spi
        self.reset = reset
        self.dc = dc
        self.cs = cs
        self.backlight = backlight
        if xstart >= 0 and ystart >= 0:
            self.xstart = xstart
            self.ystart = ystart
        elif (self.width, self.height) == (240, 240):
            self.xstart = 0
            self.ystart = 0
        elif (self.width, self.height) == (135, 240):
            self.xstart = 52
            self.ystart = 40
        else:
            raise ValueError(
                "Unsupported display. Only 240x240 and 135x240 are supported "
                "without xstart and ystart provided"
            )
        self.cmd=bytearray(1)
        self.pos=bytearray(4)
        self.colr=bytearray(2)
        self.buf=bytearray(_BUFFER_SIZE*2)

    @micropython.viper
    def command(self, command:int):
        p8=ptr8(addressof(self.cmd))
        p8[0]=command
        self.cs.off()
        self.dc.off()
        self.spi.write(self.cmd)
        self.cs.on()

    @micropython.viper
    def data(self, data):
        self.cs.off()
        self.dc.on()
        self.spi.write(data)
        self.cs.on()

    @micropython.viper
    def commandata(self, command:int, data):
        p8=ptr8(addressof(self.cmd))
        p8[0]=command
        self.cs.off()
        self.dc.off()
        self.spi.write(self.cmd)
        self.dc.on()
        self.spi.write(data)
        self.cs.on()

    @micropython.viper
    def hard_reset(self):
        self.cs.off()
        self.reset.on()
        sleep_ms(50)
        self.reset.off()
        sleep_ms(50)
        self.reset.on()
        sleep_ms(150)
        self.cs.on()

    @micropython.viper
    def soft_reset(self):
        self.command(ST77XX_SWRESET)
        sleep_ms(150)

    @micropython.viper
    def sleep_mode(self, value:int):
        if value:
            self.command(ST77XX_SLPIN)
        else:
            self.command(ST77XX_SLPOUT)

    @micropython.viper
    def inversion_mode(self, value:int):
        if value:
            self.command(ST77XX_INVON)
        else:
            self.command(ST77XX_INVOFF)

    @micropython.viper
    def _set_color_mode(self, mode:int):
        self.commandata(ST77XX_COLMOD, bytes([mode & 0x77]))

    def init(self, *args, **kwargs):
        self.hard_reset()
        self.soft_reset()
        self.sleep_mode(False)

    @micropython.viper
    def _set_mem_access_mode(self, rotation:int, vert_mirror:int, horz_mirror:int, is_bgr:int):
        value = 0
        if rotation&1:
            value |= ST7789_MADCTL_MX
        if rotation&2:
            value |= ST7789_MADCTL_MY
        if rotation&4:
            value |= ST7789_MADCTL_MV
        if vert_mirror:
            value |= ST7789_MADCTL_ML
        if horz_mirror:
            value |= ST7789_MADCTL_MH
        if is_bgr:
            value |= ST7789_MADCTL_BGR
        self.commandata(ST7789_MADCTL, bytes([value]))

    @micropython.viper
    def _encode_pos(self, x:int, y:int):
        """Encode a postion into bytes."""
        p8=ptr8(addressof(self.pos))
        p8[0]=x>>8
        p8[1]=x
        p8[2]=y>>8
        p8[3]=y

    @micropython.viper
    def _encode_pixel(self, color:int):
        """Encode a pixel color into bytes."""
        p8=ptr8(addressof(self.colr))
        p8[0]=color>>8
        p8[1]=color

    @micropython.viper
    def _set_columns(self, start:int, end:int):
        if start > end or end >= int(self.width):
            return
        start += int(self.xstart)
        end += int(self.xstart)
        self._encode_pos(start, end)
        self.commandata(ST77XX_CASET, self.pos)

    @micropython.viper
    def _set_rows(self, start:int, end:int):
        if start > end or end >= int(self.height):
            return
        start += int(self.ystart)
        end += int(self.ystart)
        self._encode_pos(start, end)
        self.commandata(ST77XX_RASET, self.pos)

    @micropython.viper
    def set_window(self, x0:int, y0:int, x1:int, y1:int):
        self._set_columns(x0, x1)
        self._set_rows(y0, y1)
        self.command(ST77XX_RAMWR)

    @micropython.viper
    def vline(self, x:int, y:int, length:int, color):
        self.fill_rect(x, y, 1, length, color)

    @micropython.viper
    def hline(self, x:int, y:int, length:int, color):
        self.fill_rect(x, y, length, 1, color)

    @micropython.viper
    def pixel(self, x:int, y:int, color):
        self._encode_pixel(color)
        self.pixel(x,y)

    @micropython.viper
    def pixel(self, x:int, y:int):
        self.set_window(x, y, x, y)
        self.data(self.colr)

    @micropython.viper
    def blit_buffer(self, buffer, x:int, y:int, width:int, height:int):
        self.set_window(x, y, x + width - 1, y + height - 1)
        self.data(buffer)

    @micropython.viper
    def rect(self, x:int, y:int, w:int, h:int, color):
        self.hline(x, y, w, color)
        self.vline(x, y, h, color)
        self.vline(x + w - 1, y, h, color)
        self.hline(x, y + h - 1, w, color)

    @micropython.viper
    def fill_rect(self, x:int, y:int, width:int, height:int, color):
        self.set_window(x, y, x + width - 1, y + height - 1)
        pixels = width * height
        chunks = pixels // int(_BUFFER_SIZE)
        rest = pixels % int(_BUFFER_SIZE)
        self._encode_pixel(color)
        p8c=ptr8(addressof(self.colr))
        p8b=ptr8(addressof(self.buf))
        for i in range(int(_BUFFER_SIZE)):
          p8b[i+i]=p8c[0]
          p8b[i+i+1]=p8c[1]
        self.cs.off()
        self.dc.on()
        for i in range(chunks):
            self.spi.write(self.buf)
        if rest:
            self.spi.write(self.buf) # FIXME fills too much, should be self.buf[0:rest] but crashes viper
        self.cs.on()

    @micropython.viper
    def fill(self, color):
        self.fill_rect(0, 0, int(self.width), int(self.height), color)

    @micropython.viper
    def line(self, x0:int, y0:int, x1:int, y1:int, color):
        # Line drawing function.  Will draw a single pixel wide line starting at
        # x0, y0 and ending at x1, y1.
        self._encode_pixel(color)
        dx=x1-x0
        if dx<0:
          dx=0-dx
        dy=y1-y0
        if dy<0:
          dy=0-dy
        steep = dy > dx
        if steep:
            x0, y0 = y0, x0
            x1, y1 = y1, x1
            dx, dy = dy, dx
        if x0 > x1:
            x0, x1 = x1, x0
            y0, y1 = y1, y0
        err = dx // 2
        if y0 < y1:
            ystep = 1
        else:
            ystep = -1
        while x0 <= x1:
            if steep:
                self.pixel(y0, x0)
            else:
                self.pixel(x0, y0)
            err -= dy
            if err < 0:
                y0 += ystep
                err += dx
            x0 += 1


class ST7789(ST77xx):
    def init(self, *, color_mode=ColorMode_65K | ColorMode_16bit):
        super().init()
        self._set_color_mode(color_mode)
        sleep_ms(50)
        self._set_mem_access_mode(4,1,1,0)
        self.inversion_mode(True)
        sleep_ms(10)
        self.command(ST77XX_NORON)
        sleep_ms(10)
        self.fill(0)
        self.command(ST77XX_DISPON)
        sleep_ms(500)
