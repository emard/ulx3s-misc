# ******* project, board and chip name *******
PROJECT = ulx3s_usbeth
BOARD = ulx3s
# 12 25 45 85
FPGA_SIZE = 12
FPGA_PACKAGE = 6bg381c
# config flash: 1:SPI (standard), 4:QSPI (quad)
FLASH_SPI = 4
# chip: is25lp032d is25lp128f s25fl164k
FLASH_CHIP = is25lp128f

# ******* design files *******
CONSTRAINTS = ../../constraints/ulx3s_v20_dif.lpf

# usually all toplevels have the same top module name
TOP_MODULE = ulx3s_usbeth

# various toplevels for building different f32c soc's
TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/ulx3s_usbeth.vhd

include files.mk

#BITSTREAM = \
#$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit \
#$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).vme \
#$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf \
#$(BOARD)_$(FPGA_SIZE)f_$(PROJECT)_flash_$(FLASH_CHIP).vme

SCRIPTS = ../../../../../../scripts
include $(SCRIPTS)/trellis_path.mk
include $(SCRIPTS)/diamond_path.mk
include $(SCRIPTS)/diamond_main.mk
