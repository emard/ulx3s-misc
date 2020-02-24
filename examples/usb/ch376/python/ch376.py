#!/usr/bin/env python3
import serial

def test():
 s = serial.Serial("/dev/ttyUSB0", 9600, timeout=1, xonxoff=0, rtscts=0)

 for value in bytearray([0x5A, 0xF0, 0xC3]):
   s.write([0x57, 0xAB, 0x06, value])
   r = s.read(1)
   print("(0x%02X expected) reply: 0x%02X" % (value ^ 0xFF, r[0]))

test()
