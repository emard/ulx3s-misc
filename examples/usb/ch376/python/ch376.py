#!/usr/bin/env python3
import serial

def test():
 s = serial.Serial("/dev/ttyUSB0", 9600, timeout=1, xonxoff=0, rtscts=0)
 
 msg = ["FAIL", "OK"]

 for value in bytearray([0x5A, 0xF0, 0xC3]):
   s.write([0x57, 0xAB, 0x06, value])
   r = s.read(1)
   if len(r):
     if (value ^ 0xFF) == r[0]:
       msg = "OK"
     else:
       msg = "FAIL"
     print("(0x%02X expected) reply: 0x%02X %s" % (value ^ 0xFF, r[0], msg))
   else:
     print("no response")

test()
