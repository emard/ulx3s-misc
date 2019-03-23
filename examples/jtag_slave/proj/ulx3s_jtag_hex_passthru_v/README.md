# JTAG slave terminal

cleanup:

    make -f makefile.trellis clean

compile:

    make -f makefile.trellis

program (upload to SRAM, temporary):

    make -f makefile.trellis program

or

    make -f makefile.trellis program_ocd

usage:

    make scan

On OLED rows have this meaning

    bin TDI
    hex TMS
    hex TDI
    hex TDO

TDO row should display JTAG ID 149511C3

