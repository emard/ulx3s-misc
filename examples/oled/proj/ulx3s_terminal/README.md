# OLED terminal

cleanup:

    make -f makefile.trellis clean

compile:

    make -f makefile.trellis

program (upload to SRAM, temporary):

    make -f makefile.trellis program

or

    make -f makefile.trellis program_ocd

usage:

    screen /dev/ttyUSB0 115200

type some text...

to exit:

    ctrl-a \

or

    ctrl-a altgr-q

# trellis-diamond difference

For bitstream compiled with diamond,
unwanted dot will appear at bottom of
each character.
