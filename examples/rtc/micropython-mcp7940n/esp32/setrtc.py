from machine import Pin, I2C
import time, ntptime, mcp7940

i2c = I2C(sda=Pin(16), scl=Pin(17), freq=400000)
mcp = mcp7940.MCP7940(i2c)

mcp.control=0
mcp.trim=-37
#mcp.battery=1
#print("battery %s" % ("enabled" if mcp.battery else "disabled"))
print("trim %+d ppm" % mcp.trim)
print("control 0x%02X" % mcp.control)
print("setting time.localtime() to NTP time using ntptime.settime()")
ntptime.settime()
print("after NTP, time.localtime() reads:")
print(time.localtime())
print("setting mcp.time=time.localtime()")
mcp.time=time.localtime()
print("after setting:")
print("battery %s" % ("enabled" if mcp.battery else "disabled"))
print("mcp.time reads:")
# Read time after setting it, repeat to see time incrementing
for i in range(3):
  print(mcp.time)
  time.sleep_ms(1000)
