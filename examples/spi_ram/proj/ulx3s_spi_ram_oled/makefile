# ******* project, board and chip name *******
PROJECT = oled_spi_ram
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
CONSTRAINTS = ../../../../constraints/ulx3s_v20_segpdi.lpf
TOP_MODULE = ulx3s_spi_ram_oled
TOP_MODULE_FILE = ../../hdl/top/$(TOP_MODULE).vhd

VERILOG_FILES =

VHDL_FILES = \
  $(TOP_MODULE_FILE) \
  ../../hdl/spi_ram_slave.vhd \
  ../../hdl/bram_true2p_2clk.vhd \
  ../../../oled/hdl/ssd1331_hex_vhdl/oled_hex_decoder.vhd \
  ../../../oled/hdl/ssd1331_hex_vhdl/oled_init_pack.vhd \
  ../../../oled/hdl/ssd1331_hex_vhdl/oled_font_pack.vhd

SCRIPTS = ../../../../scripts
include $(SCRIPTS)/trellis_path.mk
include $(SCRIPTS)/diamond_path.mk
include $(SCRIPTS)/diamond_main.mk
