# ******* project, board and chip name *******
PROJECT = dvi_in
BOARD = ulx3s
# 12 25 45 85
FPGA_SIZE = 12
FPGA_PACKAGE = 6bg381c
# config flash: 1:SPI (standard), 4:QSPI (quad)
FLASH_SPI = 4
# chip: is25lp032d is25lp128f s25fl164k
FLASH_CHIP = is25lp128f

# ******* if programming with OpenOCD *******
# using local latest openocd until in linux distribution
OPENOCD=openocd_ft232r
# default onboard usb-jtag
OPENOCD_INTERFACE=$(SCRIPTS)/ft231x.ocd
# ulx3s-jtag-passthru
#OPENOCD_INTERFACE=$(SCRIPTS)/ft231x2.ocd
# ulx2s
#OPENOCD_INTERFACE=$(SCRIPTS)/ft232r.ocd
# external jtag
#OPENOCD_INTERFACE=$(SCRIPTS)/ft2232.ocd

# ******* design files *******
CONSTRAINTS = constraints/ulx3s_v20.lpf
TOP_MODULE = top_dvi_in
TOP_MODULE_FILE = top/$(TOP_MODULE).vhd

CLK0_NAME = clk_25_dvi_in
CLK0_FILE_NAME = ../../dvi/clocks/$(CLK0_NAME).v
CLK0_OPTIONS = \
  --module=$(CLK0_NAME) \
  --clkin_name=clki         --clkin=25    \
  --clkout0_name=clk_shift0 --clkout0=125 \
  --clkout1_name=clk_shift  --clkout1=125  --phase1=60 \
  --clkout2_name=clk_pixel  --clkout2=25   --phase2=60 \
  --clkout3_name=clk_sys    --clkout3=100 \
  --reset --dynamic

VERILOG_FILES = \
  $(CLK0_FILE_NAME) \

VHDL_FILES = \
  $(TOP_MODULE_FILE) \
  ../../dvi/clocks/clk_25_dvi_in_vhd.vhd \
  ../../dvi/hdl/blink.vhd \
  ../hdl/edid_rom.vhd \
  ../hdl/tmds_deserializer.vhd \
  ../hdl/serialiser_10_to_x.vhd \
  ../hdl/dvi2vga.vhd \
  ../hdl/tmds_dekoder.vhd \
  ../../dvi/hdl/vga2dvid.vhd \
  ../../dvi/hdl/tmds_encoder.vhd \


SCRIPTS = ../../../scripts
include $(SCRIPTS)/trellis_path.mk
include $(SCRIPTS)/diamond_path.mk
include $(SCRIPTS)/diamond_main.mk
