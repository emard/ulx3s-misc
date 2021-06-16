from nmigen import *
from nmigen.build import Platform


class TMDSEncoder(Elaboratable):
    def __init__(self):
        self.i_data = Signal(8)
        self.i_c = Signal(2)
        self.i_blank = Signal()
        self.o_encoded = Signal(10)

    def elaborate(self, platform: Platform) -> Module:
        m = Module()

        xored = Signal(9, reset_less=True)
        xnored = Signal(9, reset_less=True)
        ones = Signal(4, reset_less=True)
        data_word = Signal(9, reset_less=True)
        data_word_inv = Signal(9, reset_less=True)
        data_word_disparity = Signal(4, reset_less=True)
        dc_bias = Signal(4, reset_less=True)

        m.d.comb += [
            xored[0].eq(self.i_data[0]),
            xored[1].eq(self.i_data[1] ^ xored[0]),
            xored[2].eq(self.i_data[2] ^ xored[1]),
            xored[3].eq(self.i_data[3] ^ xored[2]),
            xored[4].eq(self.i_data[4] ^ xored[3]),
            xored[5].eq(self.i_data[5] ^ xored[4]),
            xored[6].eq(self.i_data[6] ^ xored[5]),
            xored[7].eq(self.i_data[7] ^ xored[6]),
            xored[8].eq(1)
        ]

        m.d.comb += [
            xnored[0].eq(self.i_data[0]),
            xnored[1].eq(~(self.i_data[1] ^ xnored[0])),
            xnored[2].eq(~(self.i_data[2] ^ xnored[1])),
            xnored[3].eq(~(self.i_data[3] ^ xnored[2])),
            xnored[4].eq(~(self.i_data[4] ^ xnored[3])),
            xnored[5].eq(~(self.i_data[5] ^ xnored[4])),
            xnored[6].eq(~(self.i_data[6] ^ xnored[5])),
            xnored[7].eq(~(self.i_data[7] ^ xnored[6])),
            xnored[8].eq(0)
        ]

        # Count how many ones are set in data.
        m.d.comb += ones.eq(
            0b0000 +
            self.i_data[0] +
            self.i_data[1] +
            self.i_data[2] +
            self.i_data[3] +
            self.i_data[4] +
            self.i_data[5] +
            self.i_data[6] +
            self.i_data[7]
        )

        # Decide which encoding to use.
        with m.If((ones > 4) | ((ones == 4) & (self.i_data[0] == 0))):
            m.d.comb += data_word.eq(xnored)
            m.d.comb += data_word_inv.eq(~(xnored))
        with m.Else():
            m.d.comb += data_word.eq(xored)
            m.d.comb += data_word_inv.eq(~(xored))

        # Work out the DC bias of the data word.
        m.d.comb += data_word_disparity.eq(
            0b1100 +
            data_word[0] +
            data_word[1] +
            data_word[2] +
            data_word[3] +
            data_word[4] +
            data_word[5] +
            data_word[6] +
            data_word[7]
        )

        # Work out what the output should be.
        with m.If(self.i_blank):
            with m.Switch(self.i_c):
                with m.Case(0b00):
                    m.d.pixel += self.o_encoded.eq(0b1101010100)
                with m.Case(0b01):
                    m.d.pixel += self.o_encoded.eq(0b0010101011)
                with m.Case(0b10):
                    m.d.pixel += self.o_encoded.eq(0b0101010100)
                with m.Default():
                    m.d.pixel += self.o_encoded.eq(0b1010101011)
            m.d.pixel += dc_bias.eq(0)
        with m.Else():
            with m.If((dc_bias == 0) | (data_word_disparity == 0)):
                # dataword has no disparity
                with m.If(data_word[8]):
                    m.d.pixel += self.o_encoded.eq(Cat(data_word[:8], 0b01))
                    m.d.pixel += dc_bias.eq(dc_bias + data_word_disparity)
                with m.Else():
                    m.d.pixel += self.o_encoded.eq(Cat(data_word_inv[:8], 0b10))
                    m.d.pixel += dc_bias.eq(dc_bias - data_word_disparity)
            with m.Elif(((dc_bias[3] == 0) & (data_word_disparity[3] == 0)) |
                        ((dc_bias[3] == 1) & (data_word_disparity[3] == 1))):
                m.d.pixel += self.o_encoded.eq(Cat(data_word_inv[:8], data_word[8], 0b1))
                m.d.pixel += dc_bias.eq(dc_bias + data_word[8] - data_word_disparity)
            with m.Else():
                m.d.pixel += self.o_encoded.eq(Cat(data_word, 0b0))
                m.d.pixel += dc_bias.eq(dc_bias - data_word_inv[8] + data_word_disparity)

        return m
