VHDL_FILES = $(TOP_MODULE_FILE) \
  ../../../../lattice/ulx3s/clocks/clk_25M_100M_7M5_12M_60M.vhd \
  ../../../../lattice/ulx3s/clocks/clk_25_125_25_48_89.vhd \
  ../../../../lattice/ulx3s/clocks/clk_25m_200m.vhd \
  ../../../../lattice/ulx3s/clocks/clk_200m_60m_48m_12m_7m5.vhd \
  ../../../../usb11_phy_vhdl/usb_phy.vhd \
  ../../../../usb11_phy_vhdl/usb_rx_phy_48MHz.vhd \
  ../../../../usb11_phy_vhdl/usb_tx_phy.vhd \
  ../../../../usb_host_core/usbh_host_vhdl.vhd \
  ../../../../../oled/hdl/ssd1331_hex_vhdl/oled_hex_decoder.vhd \
  ../../../../../oled/hdl/ssd1331_hex_vhdl/oled_font_pack.vhd \
  ../../../../../oled/hdl/ssd1331_hex_vhdl/oled_init_pack.vhd \

VERILOG_FILES = \
  ../../../../usb_host_core/usbh_host.v \
  ../../../../usb_host_core/usbh_host_defs.v \
  ../../../../usb_host_core/usbh_sie.v \
  ../../../../usb_host_core/usbh_fifo.v \
  ../../../../usb_host_core/usbh_crc5.v \
  ../../../../usb_host_core/usbh_crc16.v \
