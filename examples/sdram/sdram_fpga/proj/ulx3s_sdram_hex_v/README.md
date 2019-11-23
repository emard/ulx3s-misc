# SDRAM from nullobject

This is
[SDRAM controller in VHDL from nullobject](https://github.com/nullobject/sdram-fpga).
It has burst support, configurable application data bus with and
configurable timings.

cleanup:

    make clean

compile:

    make

program (upload to SRAM, temporary):

    make program

or

    make program_ocd
