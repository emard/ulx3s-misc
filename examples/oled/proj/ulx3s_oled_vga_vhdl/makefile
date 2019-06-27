# ******* project, board and chip name *******
PROJECT = oled_vga
BOARD = ulx3s
# 12 25 45 85
FPGA_SIZE = 85

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
CONSTRAINTS = ../../../../constraints/ulx3s_v20_segpdi.lpf
TOP_MODULE = ulx3s_oled_vga
TOP_MODULE_FILE = top/$(TOP_MODULE).vhd

VERILOG_FILES =

VHDL_FILES = \
  $(TOP_MODULE_FILE) \
  clock/clk_25M_100M_7M5_12M_60M.vhd \
  ../../hdl/ssd1331_vga_vhdl/oled_vga.vhd \
  ../../hdl/ssd1331_hex_vhdl/oled_init_pack.vhd

SCRIPTS = ../../../../scripts
include $(SCRIPTS)/trellis_path.mk
include $(SCRIPTS)/diamond_path.mk
include $(SCRIPTS)/diamond_main.mk
