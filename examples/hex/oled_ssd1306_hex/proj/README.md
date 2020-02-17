# OLED display demo

Currently only checkered display is shown on ssd1306.
Picture X-offset is random and varies between resets.

cleanup:

    make -f makefile.trellis clean

compile:

    make -f makefile.trellis

program (upload to SRAM, temporary):

    make -f makefile.trellis program

or

    make -f makefile.trellis program_ocd

