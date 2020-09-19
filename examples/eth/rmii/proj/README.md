# ETH RMII LAN8720

Trivial demo:
Currently it only takes 50MHz clock from the module
and blinks LED. It counts number of CLK cycles when
rmii_crs=1 (RX DATA VALID).

Future development: here is working HEX output to
IPS 240*240 LED displays ST7789

cleanup:

    make -f makefile.trellis clean

compile:

    make -f makefile.trellis

program (upload to SRAM, temporary):

    make -f makefile.trellis program

or

    make -f makefile.trellis program_ocd

