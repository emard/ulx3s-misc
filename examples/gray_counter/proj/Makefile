# ******* project, board and chip name *******
PROJECT = gray_counter
BOARD = ulx3s
# 12 25 45 85
FPGA_SIZE = 12
FPGA_PACKAGE = 6bg381c

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
CONSTRAINTS = ../../../constraints/ulx3s_v20.lpf
TOP_MODULE = ulx3s_gray_counter
TOP_MODULE_FILE = top/$(TOP_MODULE).vhd

VHDL_FILES = \
  $(TOP_MODULE_FILE) \
  ../hdl/gray_counter.vhd \

VERILOG_FILES = \

# synthesis options
#YOSYS_OPTIONS = -noccu2

SCRIPTS = ../../../scripts
include $(SCRIPTS)/trellis_path.mk
include $(SCRIPTS)/diamond_path.mk
include $(SCRIPTS)/diamond_main.mk
