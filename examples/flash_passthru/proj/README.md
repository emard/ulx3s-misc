# FLASH-GPIO passthru

This is SPI FLASH passthru to external GPIO pins.
Programmer supported by
[flashrom](https://www.flashrom.org/Flashrom) utility
can be connected, like a generic FT2232 JTAG.

"flashrom" utility supports a lot of different FLASH chips.
Useful if FLASH chip is write protected or not (yet)
supported by "fujprog", "openFPGALoader" and "esp32ecp5".

| FLASH | ULX3S | FT2232 | JTAG |
|-------|-------|--------|------|
| CLK   |  GP0  | DBUS0  | TCK  |
| MOSI  |  GP1  | DBUS1  | TDI  |
| MISO  |  GP2  | DBUS2  | TDO  |
| CSn   |  GP3  | DBUS3  | TMS  |
