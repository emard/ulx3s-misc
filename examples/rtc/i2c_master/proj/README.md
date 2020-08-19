# RTC MCP7940N verilog example

i2c master example that reads time from onboard real-time-clock
chip MCP7940N. Date and time is provided in BCD format, 
suitable to be
displayed on a HEX decoder.
ST7789 LCD HEX decoder core is used.
Additionally seconds in BCD format are also displayed on LEDs.

If LEDs don't blink each second, RTC is not "ticking".
Clock must be initialized which means writing to its
registers values that enable battery operation,
set clock "speed" adjustment, set current time and start
the clock. After this seconds will be advancing and clock "ticking".

example "micropython-mcp7940n/esp32/rtcdemo.py" can be used to
initialize the clock

If lithium battery CR1225 3V is installed, clock will keep
ticking during power off. If there's no battery RTC will keep
settings and ticking only during power is on and forget settings
at power off.

