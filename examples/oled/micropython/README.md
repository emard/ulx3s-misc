# ESP32 micropython -> passthru -> OLED

This is example of micropython code running
on ESP32 and driving OLED through FPGA using
"passthru" bitstream.

# TODO

    [ ] buffer for all line commands for 1 char
        send 1 long SPI command instead of many short ones
    [ ] init sequences for 4 screen orientations
