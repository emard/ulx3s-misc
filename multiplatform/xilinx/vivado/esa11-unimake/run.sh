#!/bin/sh
FPGA_CHIP_UPPERCASE=XC7T100

CONSTRAINTS="constr1.xdc constr2.xdc"
VHDL_FILES="file1.vhd file2.vhd"
VERILOG_FILES="file3.v file4.v"
# xci files without .xci extensions
XCI_FILES="clock1 clock2"

xsltproc \
	  --stringparam FPGA_DEVICE "xc7a100tfgg484-999" \
	  --stringparam CONSTRAINTS_FILES "${CONSTRAINTS}" \
	  --stringparam TOP_MODULE "top_module123" \
	  --stringparam VHDL_FILES "${VHDL_FILES}" \
	  --stringparam VERILOG_FILES "${VERILOG_FILES}" \
	  --stringparam XCI_FILES "${XCI_FILES}" \
	  xpr.xsl empty.xpr > modified.xpr

#	  --stringparam FPGA_DEVICE $(FPGA_CHIP_UPPERCASE)-$(FPGA_PACKAGE_UPPERCASE) \
#	  --stringparam STRATEGY_FILE $(STRATEGY) \
#	  --stringparam XCF_FILE $(SCRIPTS)/$(BOARD)_sram.xcf \
#	  --stringparam TOP_MODULE $(TOP_MODULE) \
#	  --stringparam TOP_MODULE_FILE $(TOP_MODULE_FILE) \
