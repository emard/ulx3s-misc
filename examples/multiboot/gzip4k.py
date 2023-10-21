#!/usr/bin/env python3

# gzip-compress file on PC using small block size 4K,
# suitable for unzipping at devices with small RAM,
# micropython friendly

import os, sys, zlib

def gzip4k(fname_src, fname_dst):
  stream = open(fname_src, "rb")
  comp = zlib.compressobj(level=9, wbits=16 + 12)
  with open(fname_dst, "wb") as outf:
    while 1:
      data = stream.read(1024)
      if not data:
        break
      outf.write(comp.compress(data))
    outf.write(comp.flush())

if __name__ == "__main__":
  gzip4k(sys.argv[1], sys.argv[2])
