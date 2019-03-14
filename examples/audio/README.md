# Project Trellis AUDIO

Simple example generates analog and digital (SPDIF) sound output
to 24-bit SPDIF and 4-bit DAC with resolution enhancement.

Input is 12-bit unsigned PCM from a simple low frequency
triangle wave generator (something near 50 Hz). 

Because of resolution enhancement with PWM, 4-bit DAC plays smooth
sound wave. 4-bit DAC without such PWM would generate unwanted
high-pitch harmonics due to coarse quantization.

Analog output goes to 4-bit DAC with resolution enhancement
using 8-bit PWM applied to LSB (least significant bit).
Analog output is sent to TIP and RING1 of 3.5 mm jack.

Digital output goes to 24-bit signed SPDIF encoder.
12-bit unsigned wave is mapped to bits [22:11] of 24-bit signed
bus and other bits are zero.
Digital SPDIF output is sent to RING2 of 3.5 mm jack.

# TODO

[ ] verilog parametrized widths:
    https://github.com/daveshah1/CSI2Rx/blob/master/verilog_cores/phy/word_combiner.v#L33-L48
