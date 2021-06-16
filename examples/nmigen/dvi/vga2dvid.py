from nmigen import *
from nmigen.build import Platform

from tmds_encoder import TMDSEncoder


class VGA2DVID(Elaboratable):
    def __init__(self,
                 shift_clock_synchronizer = True,  # Try to get o_clk in sync with 'pixel'
                 parallel                 = True,  # Default output parallel data
                 serial                   = True,  # Default output serial data
                 ddr                      = False, # Default use SDR for serial data
                 depth                    = 8):
        self.i_red = Signal(depth)
        self.i_green = Signal(depth)
        self.i_blue = Signal(depth)
        self.i_blank = Signal()
        self.i_hsync = Signal()
        self.i_vsync = Signal()
        # Parallel outputs
        self.o_red_par = Signal(10)
        self.o_green_par = Signal(10)
        self.o_blue_par = Signal(10)
        # Serial outputs
        self.o_red = Signal(2)
        self.o_green = Signal(2)
        self.o_blue = Signal(2)
        self.o_clk = Signal(2)
        # Configuration
        self.shift_clock_synchronizer = shift_clock_synchronizer
        self.parallel = parallel
        self.serial = serial
        self.ddr = ddr
        self.depth = depth

    def elaborate(self, platform: Platform) -> Module:
        m = Module()

        # Constants
        SHIFT_CLOCK_INITIAL = C(0b0000011111)
        C_RED               = C(0b00)
        C_GREEN             = C(0b00)

        # Internal signals
        encoded_red   = Signal(10)
        encoded_green = Signal(10)
        encoded_blue  = Signal(10)

        latched_red   = Signal(10, reset=0)
        latched_green = Signal(10, reset=0)
        latched_blue  = Signal(10, reset=0)

        shift_red   = Signal(10, reset=0)
        shift_green = Signal(10, reset=0)
        shift_blue  = Signal(10, reset=0)

        shift_clock                = Signal(10, reset=SHIFT_CLOCK_INITIAL.value)
        R_shift_clock_off_sync     = Signal(reset=0)
        R_shift_clock_synchronizer = Signal(8, reset=0)
        R_sync_fail                = Signal(7)
        c_blue                     = Signal(2)

        red_d   = Signal(8)
        green_d = Signal(8)
        blue_d  = Signal(8)

        m.d.comb += c_blue.eq(Cat(self.i_hsync, self.i_vsync))
        m.d.comb += red_d[8 - self.depth:8].eq(self.i_red[8 - self.depth:8])
        m.d.comb += green_d[8 - self.depth:8].eq(self.i_green[8 - self.depth:8])
        m.d.comb += blue_d[8 - self.depth:8].eq(self.i_blue[8 - self.depth:8])

        # Fill vacant low bits with value repeated (so min/max is always 0 or 255).
        if (self.depth < 8):
            for i in range(8 - self.depth):
                m.d.comb += red_d[i].eq(self.i_red[0])
                m.d.comb += green_d[i].eq(self.i_green[0])
                m.d.comb += blue_d[i].eq(self.i_blue[0])

        if (self.shift_clock_synchronizer):
            # Sampler verifies if shift_clock state is synchronous with pixel clock
            with m.If(shift_clock[4:6] == SHIFT_CLOCK_INITIAL[4:6]):
                m.d.pixel += R_shift_clock_off_sync.eq(0)
            with m.Else():
                m.d.pixel += R_shift_clock_off_sync.eq(1)

            # Every N cycles of shift clock, signal to skip 1 cycle in order to get in sync.
            with m.If(R_shift_clock_off_sync):
                with m.If(R_shift_clock_synchronizer[-1]):
                    m.d.shift += R_shift_clock_synchronizer.eq(0)
                with m.Else():
                    m.d.shift += R_shift_clock_synchronizer.eq(R_shift_clock_synchronizer + 1)
            with m.Else():
                m.d.shift += R_shift_clock_synchronizer.eq(0)

        m.submodules.u21 = u21 = TMDSEncoder()
        m.submodules.u22 = u22 = TMDSEncoder()
        m.submodules.u23 = u23 = TMDSEncoder()

        m.d.comb += [
            u21.i_data.eq(red_d),
            u21.i_c.eq(C_RED),
            u21.i_blank.eq(self.i_blank),
            encoded_red.eq(u21.o_encoded),

            u22.i_data.eq(green_d),
            u22.i_c.eq(C_GREEN),
            u22.i_blank.eq(self.i_blank),
            encoded_green.eq(u22.o_encoded),

            u23.i_data.eq(blue_d),
            u23.i_c.eq(c_blue),
            u23.i_blank.eq(self.i_blank),
            encoded_blue.eq(u23.o_encoded),
        ]

        m.d.pixel += [
            latched_red.eq(encoded_red),
            latched_green.eq(encoded_green),
            latched_blue.eq(encoded_blue),
        ]

        if (self.parallel):
            m.d.comb += [
                self.o_red_par.eq(latched_red),
                self.o_green_par.eq(latched_green),
                self.o_blue_par.eq(latched_blue),
            ]

        # SDR
        if (self.serial and not self.ddr):
            with m.If(shift_clock[4:6] == SHIFT_CLOCK_INITIAL[4:6]):
                m.d.shift += [
                    shift_red.eq(latched_red),
                    shift_green.eq(latched_green),
                    shift_blue.eq(latched_blue)
                ]
            with m.Else():
                m.d.shift += [
                    shift_red.eq(Cat(shift_red[1:10], 0b0)),
                    shift_green.eq(Cat(shift_green[1:10], 0b0)),
                    shift_blue.eq(Cat(shift_blue[1:10], 0b0))
                ]

            with m.If(R_shift_clock_synchronizer[-1] == 0):
                m.d.shift += shift_clock.eq(Cat(shift_clock[1:10], shift_clock[:1]))
            with m.Else():
                with m.If(R_sync_fail[-1]):
                    m.d.shift += shift_clock.eq(SHIFT_CLOCK_INITIAL)
                    m.d.shift += R_sync_fail.eq(0)
                with m.Else():
                    m.d.shift += R_sync_fail.eq(R_sync_fail + 1)

        # DDR
        if (self.serial and self.ddr):
            with m.If(shift_clock[4:6] == SHIFT_CLOCK_INITIAL[4:6]):
                m.d.shift += [
                    shift_red.eq(latched_red),
                    shift_green.eq(latched_green),
                    shift_blue.eq(latched_blue)
                ]
            with m.Else():
                m.d.shift += [
                    shift_red.eq(Cat(shift_red[2:10], 0b00)),
                    shift_green.eq(Cat(shift_green[2:10], 0b00)),
                    shift_blue.eq(Cat(shift_blue[2:10], 0b00))
                ]

            with m.If(R_shift_clock_synchronizer[-1] == 0):
                m.d.shift += shift_clock.eq(Cat(shift_clock[2:10], shift_clock[:2]))
            with m.Else():
                # Synchronization failed.
                # After too many failures, reinitialize shift_clock.
                with m.If(R_sync_fail[-1]):
                    m.d.shift += shift_clock.eq(SHIFT_CLOCK_INITIAL)
                    m.d.shift += R_sync_fail.eq(0)
                with m.Else():
                    m.d.shift += R_sync_fail.eq(R_sync_fail + 1)

        # SDR: use only bit 0 from each o_* channel
        # DDR: 2 bits per 1 clock period
        # (one bit output on rising edge, other on falling edge of shift clock)
        if (self.serial):
            m.d.comb += [
                self.o_red.eq(shift_red[:2]),
                self.o_green.eq(shift_green[:2]),
                self.o_blue.eq(shift_blue[:2]),
                self.o_clk.eq(shift_clock[:2]),
            ]

        return m
