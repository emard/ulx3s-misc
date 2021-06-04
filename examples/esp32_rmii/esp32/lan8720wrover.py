# LAN8720 MODULE

#GPIO00 - EMAC_TX_CLK : nINT/REFCLK (50MHz)
#GPIO12 - SMI_MDC     : MDC (relocateable)
#GPIO4  - SMI_MDIO    : MDIO (relocateable)
#GPIO19 - EMAC_TXD0   : TX0
#GPIO21 - EMAC_TX_EN  : TX_EN
#GPIO22 - EMAC_TXD1   : TX1
#GPIO25 - EMAC_RXD0   : RX0
#GPIO26 - EMAC_RXD1   : RX1
#GPIO27 - EMAC_RX_DV  : CRS
#GND                  : GND
#3V3                  : VCC

#GPIO23 JTAG_TDI
#GPIO34 JTAG_TDO (was 19)
#GPIO18 JTAG_TCK
#GPIO5  JTAG_TMS (was 21)

import network
from machine import Pin
lan = network.LAN(mdc=Pin(12), mdio=Pin(4), power=None, id=None, phy_addr=1, phy_type=network.PHY_LAN8720)
lan.active(True)
lan.ifconfig()
#lan.ifconfig(('192.168.18.190', '255.255.255.0', '192.168.18.254', '192.168.18.254'))

# disconnect GPIO0 and GPIO12, then press power on ESP32 to boot.
# reconnect GPIO0 and GPIO12 and ctrl-D to python prompt
# LAN should connect and print IP address
# download speed with ftp from ESP32 flash is 300KB/s (3Mbps)
