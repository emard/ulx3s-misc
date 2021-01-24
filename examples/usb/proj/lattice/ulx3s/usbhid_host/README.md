# USB HID Host Core

Demo for USB HID devices. Plug mouse, keyboard or joystick,
to US2 over OTG adapter, or to US3, US3 (external PMOD),
press something and watch as OLED HEX display is changing.

vhdl version works for diamond but not for trellis,
compilation stops with this error:

    ERROR: wire not found for $posedge

