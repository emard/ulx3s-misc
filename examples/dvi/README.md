# DVI examples

Simple VGA video example
from [fpga4fun](https://www.fpga4fun.com/HDMI.html) shows
color test picture on DVI monitor.
VGA video signal (8-bit RGB, hsync, vsync, blank)
is converted to 10-bit digital video, serialized with DDR/SDR option,
and sent to single-ended otputs as fake differential signal.
It works on ULX3S with latest prjtrellis.

For prjtrellis, compile and program it with:

    make clean; make program

Same source can also be compiled with Lattice Diamond:

    make -f makefile.diamond; make -f makefile.diamond program

# Flexible video modes

To change video mode, just edit the toplevel
"top/top_vgatest.v" and enter desired screen
resolution and frame refresh frequency, like:

    parameter x =  640,      // pixels
    parameter y =  480,      // pixels
    parameter f =   60,      // Hz 60,50,30

or

    parameter x = 1024,      // pixels
    parameter y =  768,      // pixels
    parameter f =   60,      // Hz 60,50,30

This project features compile-time evaluated constant
functions which calculate ECP5 PLL parameters and
video timings that work for digital LCD displays.
This is probably not suitable for analog CRT displays.

Without overclock max resolution is
1920x1080@30Hz, but some monitors will not accept 30Hz.
Higher modes with 50Hz are more compatible
but involve ECP5 oveclock much above official 400MHz max:

    1920x1080@50Hz 540MHz
    1920x1200@50Hz 600MHz

If monitor doesn't show correct refresh rate,
it can be fine tuned. Negative values will raise
refresh rate. Positive values will lower refresh rate.

    parameter xadjustf =  0, // adjust -3..3 if no picture
    parameter yadjustf =  0, // or to get correct f
