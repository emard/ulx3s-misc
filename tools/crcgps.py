#!/usr/bin/env python3
from functools import reduce
from operator import xor

a=bytearray(b"PGRMO,GPVTG,0")
print(a)
crc = b"*%02X\r\n" % reduce(xor, map(int, a))
print(b"$"+a+crc)
