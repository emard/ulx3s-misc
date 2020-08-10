from machine import SDCard
from os import mount,umount,listdir
from time import ticks_ms

def mnt():
  mount(SDCard(),"/sd") # 4-bit mode
  #mount(SDCard(slot=3),"/sd") # 1-bit mode
  print(listdir("/sd"))
  f=open("/sd/long_file.bin","rb") # any 1-10 MB long file
  b=bytearray(1024)
  i=0
  t1=ticks_ms()
  while f.readinto(b):
    i+=1
  t2=ticks_ms()
  print("%d KB in %d ms => %d KB/s" % (i,t2-t1,1000*i//(t2-t1)))
  f.close()
  umount("/sd")

mnt()
