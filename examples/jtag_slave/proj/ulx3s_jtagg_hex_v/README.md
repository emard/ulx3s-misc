# JTAGG vendor specific demo

JTAGG module allows user bitstream to receive JTAG traffic from
standard JTAG pins. JTAG master (openocd SVF in this example)
needs to send few vendor specific JTAG commands to put vendor-specific
JTAG slave interface into bypass state.

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

TDI row should display 0x600DBABE

# Links

[HADBADGE verilog core](https://github.com/Spritetm/hadbadge2019_fpgasoc/blob/4ae8277c45e17e316bb4d46ce625c1507506cd36/soc/top_fpga.v#L312-L322)

[HADBADGE svf generator](https://github.com/Spritetm/hadbadge2019_fpgasoc/blob/master/soc/jtagload/main.c)
