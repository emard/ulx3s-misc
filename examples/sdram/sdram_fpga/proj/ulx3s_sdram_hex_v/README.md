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

# OLED should display:

left 32-bit should quicky alternate word to be written
"01234567" and "600DCAFE". Hold BTN1 to freeze display
to be able to read.

right 32-bit should show word that has been read from RAM:
it should be "01234567". Hold BTN2 and it should show "600DCAFE".
