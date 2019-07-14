#!/usr/bin/env python3

# round-trip test of ascii mode

import os
import sys
import getopt
import serial
import time
import struct


print("ASCII round-trip test v1.0")
usb_serial_device_name = "/dev/ttyACM0"
serial_baud_default = 115200
serial_timeout = 0.2
serial_port=serial.Serial(usb_serial_device_name, serial_baud_default, rtscts=False, timeout=serial_timeout)

# construct test and receive verify string
def test(length):
  # print("round-trip test length", length)
  test_send = b""
  test_recv = b""
  for i in range(length):
    test_send += struct.pack("B", (i%32)+48)
    test_recv += struct.pack("B", ((length-i-1)%32+48))
  test_send += b"\r"
  test_recv += b"\r\n"
  #serial_port.write(b"123457\r")
  serial_port.write(test_send)
  serial_port.flush()
  reply = serial_port.read(len(test_recv))
  if len(reply) == len(test_recv):
    # print("OK received length", len(reply))
    dummy = 0
  else:
    print("ERROR received length: %d expected %d" % (len(reply), len(test_recv))) 
    print(reply)
    print(test_recv)

for i in range(900,1020):
  test(i)
