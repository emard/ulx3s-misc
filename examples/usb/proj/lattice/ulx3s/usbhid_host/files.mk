VHDL_FILES = $(TOP_MODULE_FILE) \
  ../../../../lattice/ulx3s/clocks/clk_25M_100M_7M5_12M_60M.vhd \
  ../../../../lattice/ulx3s/clocks/clk_25_125_25_48_89.vhd \
  ../../../../lattice/ulx3s/clocks/clk_25m_200m.vhd \
  ../../../../lattice/ulx3s/clocks/clk_200m_60m_48m_12m_7m5.vhd \
  ../../../../lattice/ulx3s/clocks/clk_25_125_68_6_25.vhd \
  ../../../../usb11_phy_vhdl/usb_phy.vhd \
  ../../../../usb11_phy_vhdl/usb_rx_phy.vhd \
  ../../../../usb11_phy_vhdl/usb_tx_phy.vhd \
  ../../../../usbhost/usbh_setup_pack.vhd \
  ../../../../usbhost/usbh_host_hid.vhd \
  ../../../../usbhost/usbh_sie_vhdl.vhd \
  ../../../../../oled/hdl/ssd1331_hex_vhdl/oled_hex_decoder.vhd \
  ../../../../../oled/hdl/ssd1331_hex_vhdl/oled_font_pack.vhd \
  ../../../../../oled/hdl/ssd1331_hex_vhdl/oled_init_pack.vhd \
  ../../../../../dvi/hdl/vga.vhd \
  ../../../../../dvi/hdl/vga2dvid.vhd \
  ../../../../../dvi/hdl/tmds_encoder.vhd \

# not used yet
#  ../../../../usbhid/report_decoded_pack_generic.vhd \
#  ../../../../usbhid/usbhid_report_decoder_saitek_joystick.vhd \

VERILOG_FILES = \
  ../../../../usbhost/usbh_sie.v \
  ../../../../usbhost/usbh_crc5.v \
  ../../../../usbhost/usbh_crc16.v \
