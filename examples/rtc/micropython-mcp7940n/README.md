# RTC demo with e-ink display

This example demonstrates low-power features, shutdown and wake-on-RTC.

Every minute board will wake, connect to WiFi, update RTC from NTP 
display time on e-ink display and shutdown.

If NTP is available, "NT" will be displayed.
If NTP is not available, "MC" will be displayed
and clock will keep on working solely from RTC.

RTC battery CR1225 3V should be installed.

ESP32 micropython code handles i2c, RTC, NTP and e-ink display.

FPGA core is just bypass for i2c, SPI and shutdown logic and
should be written to config FLASH for this example to work.

Links:
[RTC](https://github.com/mattytrentini/micropython-mcp7940)
