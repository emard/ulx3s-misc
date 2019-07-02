# SPI OLED VGA core in VHDL

This VHDL core (when finished) takes VGA style input
(pixel clock, RGB pixel data, vsync, hsync, blank)
and display it as video on OLED screen.

overscan - runs both VGA and OLED at the same clock domain

VGA generates faster frame rate than SPI can send.
SPI sends by its speed and waits until both XY counters match
to update next pixel.

for fast frame updates, VGA generator needs to be slowed down by clk_pixel_ena
otherwise it can work also but screen update will be unacceptably slow (0.5Hz frame rate)

