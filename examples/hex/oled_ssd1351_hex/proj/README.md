# OLED HEX display demo

SSD1351 initializes to random color pixel screen,
(picture is slightly dim). content is not yet shown

cleanup:

    make -f makefile.trellis clean

compile:

    make -f makefile.trellis

program (upload to SRAM, temporary):

    make -f makefile.trellis program

or

    make -f makefile.trellis program_ocd

