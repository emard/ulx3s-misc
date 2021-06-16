# DVI example
This is from [ulx3s-nmigen-examples](https://github.com/GuzTech/ulx3s-nmigen-examples)
the [nMigen](https://github.com/nmigen/nmigen) port of the [DVI example](https://github.com/emard/ulx3s-misc/tree/master/examples/dvi) for the [ULX3S FPGA board](https://ulx3s.github.io/). Most of the original code was written by [Michael Field](https://github.com/hamsternz).

To build this example, you need [Yosys](https://github.com/YosysHQ/yosys), [nextpnr](https://github.com/YosysHQ/nextpnr), [project Trellis](https://github.com/YosysHQ/prjtrellis), and [openFPGAloader](https://github.com/trabucayre/openFPGALoader) installed. Then simply execute:

```bash
python top_vgatest.py <FPGA variant>
```

where `<FPGA variant>` is either `12F`, `25F`, `45F`, or `85F` depending on the size of the FPGA on your ULX3S board. I have an `85F` board so I run:

```bash
python top_vgatest.py 85F
```

# Flexible video modes
To change the video mode, change the parameter passed to the `TopVGA` class:

```python
m.submodules.top = top = TopVGATest(timing=vga_timings['1920x1080@30Hz'])
```

Check the `dvi/vga_timings.py` file for all available video modes. You can also add your own video modes to that file as well.

If you get a timing failure during the place and route (PnR) step, you could adjust the number of bits used for the horizontal and vertical counters (`bits_x` and `bits_y`) of the `VGA` class:

```python
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
```

Without an overclock, the maximum resolution is 1920x1080@30Hz, but some monitors will not accept 30Hz. If monitor doesn't show the correct refresh rate, then it can be fine tuned. Negative values will raise refresh rate. Positive values will lower refresh rate.

```python
xadjustf=0, # adjust -3..3 if no picture
yadjustf=0, # or to fine-tune f
```
