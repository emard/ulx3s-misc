# SDRAM from OBERON with OLED HEX demo

This SDRAM controller works in Oberon
but I don't understand its signaling
so testbench is not fully useful.

cleanup:

    make -f makefile.trellis clean

compile:

    make -f makefile.trellis

program (upload to SRAM, temporary):

    make -f makefile.trellis program

or

    make -f makefile.trellis program_ocd

