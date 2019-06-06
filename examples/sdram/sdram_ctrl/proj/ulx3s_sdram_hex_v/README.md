# SDRAM from OBERON with OLED HEX demo

This SDRAM controller is from fpga4fun.
Something works but I'm not sure about
is signaling done right.

cleanup:

    make -f makefile.trellis clean

compile:

    make -f makefile.trellis

program (upload to SRAM, temporary):

    make -f makefile.trellis program

or

    make -f makefile.trellis program_ocd

