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
TOP_MODULE = top_v20_dvi_in
#CONSTRAINTS = constraints/ulx3s_v31.lpf
#TOP_MODULE = top_v31_dvi_in
TOP_MODULE_FILE = top/$(TOP_MODULE).vhd

VHDL_FILES = \
  $(TOP_MODULE_FILE) \
  ../../ecp5pll/hdl/vhd/ecp5pll.vhd \
  ../../dvi/hdl/blink.vhd \
  ../hdl/edid_rom.vhd \
  ../hdl/tmds_deserializer.vhd \
  ../hdl/serialiser_10_to_x.vhd \
  ../hdl/dvi2vga.vhd \
  ../hdl/tmds_dekoder.vhd \
  ../../dvi/hdl/vga2dvid.vhd \
  ../../dvi/hdl/tmds_encoder.vhd \
  ../../spi_display/hdl/spi_display_verilog/lcd_video_vhd.vhd \
  ../../hex/decoder/hex_decoder.vhd \

VERILOG_FILES = \
  ../../spi_display/hdl/spi_display_verilog/lcd_video.v \
  ../../hex/decoder/hex_decoder_v.v \


SCRIPTS = ../../../scripts
include $(SCRIPTS)/trellis_path.mk
include $(SCRIPTS)/diamond_path.mk
include $(SCRIPTS)/diamond_main.mk
