# OLED HEX display demo

SSD1351 initializes to random color pixel screen,
picture is slightly dim, probably it's normal for larger OLEDs.

cleanup:

    make -f makefile.trellis clean

compile:

    make -f makefile.trellis

program (upload to SRAM, temporary):

    make -f makefile.trellis program

or

    make -f makefile.trellis program_ocd

