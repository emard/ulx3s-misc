# SDRAM from OBERON with OLED HEX demo

This is
[SDRAM controller from fpga4fun](https://www.fpga4fun.com/SDRAM2.html).

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

