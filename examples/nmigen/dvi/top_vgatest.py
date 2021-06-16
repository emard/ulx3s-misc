import argparse

from nmigen import *
from nmigen.build import *
from nmigen_boards.ulx3s import *

from blink import Blink
from vga2dvid import VGA2DVID
from vga import VGA
from vga_timings import *
from ecp5pll import ECP5PLL

#  Modes tested on an ASUS monitor:
#
#  640x350  @70Hz
#  640x350  @85Hz (out of range, but works)
#  640x400  @70Hz
#  640x400  @85Hz (out of range)
#  640x480  @60Hz
#  720x400  @85Hz (out of range)
#  720x576  @60Hz
#  720x576  @72Hz
#  720x576  @75Hz
#  800x600  @60Hz
#  848x480  @60Hz
# 1024x768  @60Hz
# 1152x864  @60Hz (does not synthesize)
# 1280x720  @60Hz
# 1280x768  @60Hz (requires slight overclock)
# 1280x768  @60Hz CVT-RB
# 1280x800  @60Hz (does not synthesize)
# 1280x800  @60Hz CVT
# 1366x768  @60Hz (does not synthesize)
# 1280x1024 @60Hz (does not synthesize)
# 1920x1080 @30Hz (monitor says 50Hz, but works)
# 1920x1080 @30Hz CVT-RB (syncs, but black screen)
# 1920x1080 @30Hz CVT-RB2 (syncs, but black screen)
# 1920x1080 @60Hz (does not synthesize)
class TopVGATest(Elaboratable):
    def __init__(self,
                 timing: VGATiming, # VGATiming class
                 xadjustf=0, # adjust -3..3 if no picture
                 yadjustf=0, # or to fine-tune f
                 ddr=True): # False: SDR, True: DDR
        self.i_btn = Signal(7)
        self.o_led = Signal(8)
        self.o_gpdi_dp = Signal(4)
        self.o_user_programn = Signal()
        self.o_wifi_gpio0 = Signal()
        # Configuration
        self.timing = timing
        self.x = timing.x
        self.y = timing.y
        self.f = timing.pixel_freq
        self.xadjustf = xadjustf
        self.yadjustf = yadjustf
        self.ddr = ddr

    def elaborate(self, platform: Platform) -> Module:
        m = Module()

        if platform:
            clk_in = platform.request(platform.default_clk, dir='-')[0]

            # Constants
            pixel_f     = self.timing.pixel_freq
            hsync_front_porch = self.timing.h_front_porch
            hsync_pulse_width = self.timing.h_sync_pulse
            hsync_back_porch  = self.timing.h_back_porch
            vsync_front_porch = self.timing.v_front_porch
            vsync_pulse_width = self.timing.v_sync_pulse
            vsync_back_porch  = self.timing.v_back_porch

            # o_wifi_gpio0 = 1 keeps board from rebooting
            # Hold btn0 to let ESP32 take control of the board.
            m.d.comb += self.o_wifi_gpio0.eq(self.i_btn[0])

            # Press btn0 to exit this bitstream.
            R_delay_reload = Signal(20, reset=0)
            with m.If(R_delay_reload[19] == 0):
                m.d.sync += R_delay_reload.eq(R_delay_reload + 1)
            m.d.comb += self.o_user_programn.eq((~self.i_btn[0]) | (~R_delay_reload[19]))

            # Clock generator.
            m.domains.sync  = cd_sync  = ClockDomain("sync")
            m.domains.pixel = cd_pixel = ClockDomain("pixel")
            m.domains.shift = cd_shift = ClockDomain("shift")

            m.submodules.ecp5pll = pll = ECP5PLL()
            pll.register_clkin(clk_in,  platform.default_clk_frequency)
            pll.create_clkout(cd_sync,  platform.default_clk_frequency)
            pll.create_clkout(cd_pixel, pixel_f)
            pll.create_clkout(cd_shift, pixel_f * 5.0 * (1.0 if self.ddr else 2.0))

            platform.add_clock_constraint(cd_sync.clk,  platform.default_clk_frequency)
            platform.add_clock_constraint(cd_pixel.clk, pixel_f)
            platform.add_clock_constraint(cd_shift.clk, pixel_f * 5.0 * (1.0 if self.ddr else 2.0))

            # VGA signal generator.
            vga_r = Signal(8)
            vga_g = Signal(8)
            vga_b = Signal(8)
            vga_hsync = Signal()
            vga_vsync = Signal()
            vga_blank = Signal()

            m.submodules.vga = vga = VGA(
                resolution_x      = self.timing.x,
                hsync_front_porch = hsync_front_porch,
                hsync_pulse       = hsync_pulse_width,
                hsync_back_porch  = hsync_back_porch,
                resolution_y      = self.timing.y,
                vsync_front_porch = vsync_front_porch,
                vsync_pulse       = vsync_pulse_width,
                vsync_back_porch  = vsync_back_porch,
                bits_x            = 16, # Play around with the sizes because sometimes
                bits_y            = 16  # a smaller/larger value will make it pass timing.
            )
            m.d.comb += [
                vga.i_clk_en.eq(1),
                vga.i_test_picture.eq(1),
                vga.i_r.eq(0),
                vga.i_g.eq(0),
                vga.i_b.eq(0),
                vga_r.eq(vga.o_vga_r),
                vga_g.eq(vga.o_vga_g),
                vga_b.eq(vga.o_vga_b),
                vga_hsync.eq(vga.o_vga_hsync),
                vga_vsync.eq(vga.o_vga_vsync),
                vga_blank.eq(vga.o_vga_blank),
            ]

            # VGA to digital video converter.
            tmds = [Signal(2) for i in range(4)]
            m.submodules.vga2dvid = vga2dvid = VGA2DVID(ddr=self.ddr, shift_clock_synchronizer=False)
            m.d.comb += [
                vga2dvid.i_red.eq(vga_r),
                vga2dvid.i_green.eq(vga_g),
                vga2dvid.i_blue.eq(vga_b),
                vga2dvid.i_hsync.eq(vga_hsync),
                vga2dvid.i_vsync.eq(vga_vsync),
                vga2dvid.i_blank.eq(vga_blank),
                tmds[3].eq(vga2dvid.o_clk),
                tmds[2].eq(vga2dvid.o_red),
                tmds[1].eq(vga2dvid.o_green),
                tmds[0].eq(vga2dvid.o_blue),
            ]

            # LED blinky
            counter_width = 28
            countblink = Signal(8)
            m.submodules.blink = blink = Blink(counter_width)
            m.d.comb += [
                countblink.eq(blink.o_led),
                self.o_led[6:8].eq(countblink[6:8]),
                self.o_led[0].eq(vga_vsync),
                self.o_led[1].eq(vga_hsync),
                self.o_led[2].eq(vga_blank),
            ]

            if (self.ddr):
                # Vendor specific DDR modules.
                # Convert SDR 2-bit input to DDR clocked 1-bit output (single-ended)
                # onboard GPDI.
                m.submodules.ddr0_clock = Instance("ODDRX1F",
                    i_SCLK = ClockSignal("shift"),
                    i_RST  = 0b0,
                    i_D0   = tmds[3][0],
                    i_D1   = tmds[3][1],
                    o_Q    = self.o_gpdi_dp[3])
                m.submodules.ddr0_red   = Instance("ODDRX1F",
                    i_SCLK = ClockSignal("shift"),
                    i_RST  = 0b0,
                    i_D0   = tmds[2][0],
                    i_D1   = tmds[2][1],
                    o_Q    = self.o_gpdi_dp[2])
                m.submodules.ddr0_green = Instance("ODDRX1F",
                    i_SCLK = ClockSignal("shift"),
                    i_RST  = 0b0,
                    i_D0   = tmds[1][0],
                    i_D1   = tmds[1][1],
                    o_Q    = self.o_gpdi_dp[1])
                m.submodules.ddr0_blue  = Instance("ODDRX1F",
                    i_SCLK = ClockSignal("shift"),
                    i_RST  = 0b0,
                    i_D0   = tmds[0][0],
                    i_D1   = tmds[0][1],
                    o_Q    = self.o_gpdi_dp[0])
            else:
                m.d.comb += [
                    self.o_gpdi_dp[3].eq(tmds[3][0]),
                    self.o_gpdi_dp[2].eq(tmds[2][0]),
                    self.o_gpdi_dp[1].eq(tmds[1][0]),
                    self.o_gpdi_dp[0].eq(tmds[0][0]),
                ]

        return m


if __name__ == "__main__":
    variants = {
        '12F': ULX3S_12F_Platform,
        '25F': ULX3S_25F_Platform,
        '45F': ULX3S_45F_Platform,
        '85F': ULX3S_85F_Platform
    }

    # Figure out which FPGA variant we want to target...
    parser = argparse.ArgumentParser()
    parser.add_argument('variant', choices=variants.keys())
    args = parser.parse_args()

    platform = variants[args.variant]()

    m = Module()
    m.submodules.top = top = TopVGATest(timing=vga_timings['1280x800@60Hz CVT-RB'])

    leds = [platform.request("led", 0),
            platform.request("led", 1),
            platform.request("led", 2),
            platform.request("led", 3),
            platform.request("led", 4),
            platform.request("led", 5),
            platform.request("led", 6),
            platform.request("led", 7)]

    for i in range(len(leds)):
        m.d.comb += leds[i].eq(top.o_led[i])

    btns = [platform.request("button_pwr"),
            platform.request("button_fire", 0),
            platform.request("button_fire", 1),
            platform.request("button_up"),
            platform.request("button_down"),
            platform.request("button_left"),
            platform.request("button_right")]

    for i in range(len(btns)):
        m.d.comb += top.i_btn[i].eq(btns[i])

    hdmi = platform.request("hdmi")
    for i in range(len(hdmi.d.o)):
        m.d.comb += hdmi.d.o[i].eq(top.o_gpdi_dp[i])
    m.d.comb += hdmi.clk.eq(top.o_gpdi_dp[3])

    user_program = platform.request("program")

    # m.d.comb += user_program.eq(top.o_user_programn)
    m.d.comb += leds[4].eq(top.o_user_programn)

    platform.build(m, do_program=True, nextpnr_opts="--timing-allow-fail")
