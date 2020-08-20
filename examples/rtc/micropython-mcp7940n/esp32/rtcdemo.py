import mcp7940
from machine import Pin, I2C
import utime as time

i2c = I2C(sda=Pin(16), scl=Pin(17), freq=400000)
mcp = mcp7940.MCP7940(i2c)

mcp.init0()
mcp.time # Read time
mcp.time = time.localtime() # Set time
mcp.battery_backup_enable(1)
mcp.start() # Start MCP oscillator
print(mcp.time) # Read time after setting it, repeat to see time incrementing
