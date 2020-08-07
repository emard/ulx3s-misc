# RTC demo with e-ink display

This example demonstrates low-power features, shutdown and wake-on-RTC.

Every minute board will power ON, connect to WiFi, update RTC from NTP 
display time on e-ink display and power OFF.

If NTP is available, "NT" will be displayed.
If NTP is not available, "MC" will be displayed
and clock will keep on working solely from RTC MCP7940N.

ESP32 micropython code handles i2c, RTC, NTP and e-ink display.

FPGA bitstream bridges i2c, SPI and shutdown fuze logic.

# Requirements

RTC battery CR1225 3V

e-ink display Heltec 1.54" V2 200x200 Black&White.

ULX3S has to power OFF and ON each minute.

Power ULX3S from US2 connector to allow automatic power OFF and ON.
Press BTN0 to start process for the first time.

When powered from US1, ULX3S will not power OFF by default.
FT231X could be reconfigured to allow power OFF from US1 by
turning OFF green LED D18.

Bitstream should be compiled with diamond
(trellis bidirectional vector issues)
and written to config FLASH for this example to work
(make flash or ujprog -j flash bitstream.bit)

# Links

[RTC](https://github.com/mattytrentini/micropython-mcp7940)
