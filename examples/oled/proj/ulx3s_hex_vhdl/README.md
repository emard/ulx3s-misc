# SPI OLED core in VHDL

This VHDL core displays HEX digits at SSD1331 color OLED display,
showing realtime state of input parallel bus. It's useful 
for onboard debugging.

After a fixed initialization sequence is sent to OLED,
state machine continuoulsy decodes input bus state to HEX
digits and displays it using simple 7x5 font.

# TODO

It copies input bus state to a register and with
MUX fetches parts of it to be decoded and diplayed
to OLED's using its feature to sequentially increments
write pointer after each write.

The MUX is not optimal to have in FPGA. It would be probably
better to only shift bus state, fetching its data sequentially
and from the state machine send commands which will change 
OLED's write pointer.
