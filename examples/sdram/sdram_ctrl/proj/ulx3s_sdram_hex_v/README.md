# SDRAM from OBERON with OLED HEX demo

This is
[SDRAM controller from fpga4fun](https://www.fpga4fun.com/SDRAM2.html).
Seems to me like it doesn't work (read address ignored).
Maybe SDRAM is not initialized...?

cleanup:

    make -f makefile.trellis clean

compile:

    make -f makefile.trellis

program (upload to SRAM, temporary):

    make -f makefile.trellis program

or

    make -f makefile.trellis program_ocd

