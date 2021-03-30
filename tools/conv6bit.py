#!/usr/bin/env python3
m = bytearray("$PGRMC,1.23,-5,+6*ABCD\n", "utf-8")
c = m
d = m
print(m)
for i in range(len(m)):
  # convert control chars < 32 to space 32
  if (c[i] & 0x60) == 0:
    c[i] = 0x20
  # convert uppercase letters >= 64 to control chars < 32
  if c[i] & 0x40:
    c[i] ^= 0x40
print(c)
for i in range(len(m)):
  # convert control chars < 32 to letters >= 64
  if (d[i] & 0x20) == 0:
    d[i] ^= 0x40
print(d)
