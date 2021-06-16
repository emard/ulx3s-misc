from nmigen import *
from nmigen.build import Platform


# Generates a VGA picture from sequential bitmap data from pixel clock
# synchronous FIFO.
#
# The pixel data in i_r, i_g, and i_b registers
# should be present ahead of time.
#
# Signal 'o_fetch_next' is set high for 1 'pixel' clock
# period as soon as current pixel data is consumed.
# The FIFO should be fast enough to fetch new data
# for the new pixel.
class VGA(Elaboratable):
    def __init__(self,
                 resolution_x      = 640,
                 hsync_front_porch = 16,
                 hsync_pulse       = 96,
                 hsync_back_porch  = 48, #44,
                 resolution_y      = 480,
                 vsync_front_porch = 10,
                 vsync_pulse       = 2,
                 vsync_back_porch  = 33, #31,
                 bits_x            = 10, # should fit resolution_x + hsync_front_porch + hsync_pulse + hsync_back_porch
                 bits_y            = 10, # should fit resolution_y + vsync_front_porch + vsync_pulse + vsync_back_porch
                 dbl_x             = False,
                 dbl_y             = False):
        self.i_clk_en       = Signal()
        self.i_test_picture = Signal()
        self.i_r            = Signal(8)
        self.i_g            = Signal(8)
        self.i_b            = Signal(8)
        self.o_fetch_next   = Signal()
        self.o_beam_x       = Signal(bits_x)
        self.o_beam_y       = Signal(bits_y)
        self.o_vga_r        = Signal(8)
        self.o_vga_g        = Signal(8)
        self.o_vga_b        = Signal(8)
        self.o_vga_hsync    = Signal()
        self.o_vga_vsync    = Signal()
        self.o_vga_vblank   = Signal()
        self.o_vga_blank    = Signal()
        self.o_vga_de       = Signal()
        # Configuration
        self.resolution_x     = resolution_x
        self.hsync_front_port = hsync_front_porch
        self.hsync_pulse      = hsync_pulse
        self.hsync_back_porch = hsync_back_porch
        self.resolution_y     = resolution_y
        self.vsync_front_port = vsync_front_porch
        self.vsync_pulse      = vsync_pulse
        self.vsync_back_porch = vsync_back_porch
        self.bits_x           = bits_x
        self.bits_y           = bits_y

    def elaborate(self, platform: Platform) -> Module:
        m = Module()

        # Constants
        C_hblank_on  = C(self.resolution_x - 1, unsigned(self.bits_x))
        C_hsync_on   = C(self.resolution_x + self.hsync_front_port - 1, unsigned(self.bits_x))
        C_hsync_off  = C(self.resolution_x + self.hsync_front_port + self.hsync_pulse - 1, unsigned(self.bits_x))
        C_hblank_off = C(self.resolution_x + self.hsync_front_port + self.hsync_pulse + self.hsync_back_porch - 1, unsigned(self.bits_x))
        C_frame_x    = C_hblank_off
        # frame x = 640 + 16 + 96 + 48 = 800

        C_vblank_on  = C(self.resolution_y - 1, unsigned(self.bits_y))
        C_vsync_on   = C(self.resolution_y + self.vsync_front_port - 1, unsigned(self.bits_y))
        C_vsync_off  = C(self.resolution_y + self.vsync_front_port + self.vsync_pulse - 1, unsigned(self.bits_y))
        C_vblank_off = C(self.resolution_y + self.vsync_front_port + self.vsync_pulse + self.vsync_back_porch - 1, unsigned(self.bits_y))
        C_frame_y    = C_vblank_off
        # frame y = 480 + 10 + 2 + 33 = 525
        # refresh rate = pixel clock / (frame x * frame y) = 25 MHz / (800 * 525) = 59.52 Hz

        # Internal signals
        CounterX      = Signal(self.bits_x)
        CounterY      = Signal(self.bits_y)
        R_hsync       = Signal()
        R_vsync       = Signal()
        R_blank       = Signal()
        R_disp        = Signal() # disp == not blank
        R_disp_early  = Signal()
        R_vdisp       = Signal()
        R_blank_early = Signal()
        R_vblank      = Signal()
        R_fetch_next  = Signal()
        R_vga_r       = Signal(8)
        R_vga_g       = Signal(8)
        R_vga_b       = Signal(8)
        # Test picture generation
        W             = Signal(8)
        A             = Signal(8)
        T             = Signal(8)
        Z             = Signal(6)

        with m.If(self.i_clk_en):
            with m.If(CounterX == C_frame_x):
                m.d.pixel += CounterX.eq(0)

                with m.If(CounterY == C_frame_y):
                    m.d.pixel += CounterY.eq(0)
                with m.Else():
                    m.d.pixel += CounterY.eq(CounterY + 1)
            with m.Else():
                m.d.pixel += CounterX.eq(CounterX + 1)

            m.d.pixel += R_fetch_next.eq(R_disp_early)
        with m.Else():
            m.d.pixel += R_fetch_next.eq(0)

        m.d.comb += [
            self.o_beam_x.eq(CounterX),
            self.o_beam_y.eq(CounterY),
            self.o_fetch_next.eq(R_fetch_next),
        ]

        # Generate sync and blank.
        with m.If(CounterX == C_hblank_on):
            m.d.pixel += [
                R_blank_early.eq(1),
                R_disp_early.eq(0)
            ]
        with m.Elif(CounterX == C_hblank_off):
            m.d.pixel += [
                R_blank_early.eq(R_vblank),
                R_disp_early.eq(R_vdisp)
            ]
        with m.If(CounterX == C_hsync_on):
            m.d.pixel += R_hsync.eq(1)
        with m.Elif(CounterX == C_hsync_off):
            m.d.pixel += R_hsync.eq(0)

        with m.If(CounterY == C_vblank_on):
            m.d.pixel += [
                R_vblank.eq(1),
                R_vdisp.eq(0)
            ]
        with m.Elif(CounterY == C_vblank_off):
            m.d.pixel += [
                R_vblank.eq(0),
                R_vdisp.eq(1)
            ]
        with m.If(CounterY == C_vsync_on):
            m.d.pixel += R_vsync.eq(1)
        with m.Elif(CounterY == C_vsync_off):
            m.d.pixel += R_vsync.eq(0)

        # Test picture generator

        m.d.comb += [
            A.eq(Mux(
                (CounterX[5:8] == 0b010) & (CounterY[5:8] == 0b010),
                0xFF, 0)),
            W.eq(Mux(
                (CounterX[:8] == CounterY[:8]),
                0xFF, 0)),
            Z.eq(Mux(
                (CounterY[3:5] == ~(CounterX[3:5])),
                0xFF, 0)),
            T.eq(Repl(CounterY[6], len(T))),
        ]

        with m.If(R_blank):
            m.d.pixel += [
                R_vga_r.eq(0),
                R_vga_g.eq(0),
                R_vga_b.eq(0),
            ]
        with m.Else():
            m.d.pixel += [
                R_vga_r.eq((Cat(0b00, CounterX[:6] & Z) | W) & (~A)),
                R_vga_g.eq(((CounterX[:8] & T) | W) & (~A)),
                R_vga_b.eq(CounterY[:8] | W | A),
            ]
        m.d.pixel += R_blank.eq(R_blank_early)
        m.d.pixel += R_disp.eq(R_disp_early)

        m.d.comb += [
            self.o_vga_r.eq(R_vga_r),
            self.o_vga_g.eq(R_vga_g),
            self.o_vga_b.eq(R_vga_b),
            self.o_vga_hsync.eq(R_hsync),
            self.o_vga_vsync.eq(R_vsync),
            self.o_vga_blank.eq(R_blank),
            self.o_vga_de.eq(R_disp),
        ]

        return m
