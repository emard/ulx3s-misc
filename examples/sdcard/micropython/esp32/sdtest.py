from machine import SDCard
from os import mount,umount,listdir
from time import ticks_ms

def run():
  #sd=SDCard() # 4-bit mode
  sd=SDCard(slot=3) # 1-bit mode
  mount(sd,"/sd")
  print(listdir("/sd"))
  f=open("/sd/long_file.bin","rb") # any 1-10 MB long file
  b=bytearray(16384)
  i=0
  t1=ticks_ms()
  while f.readinto(b):
    i+=1
  t2=ticks_ms()
  print("%d KB in %d ms => %d KB/s file read" % (i*len(b)//1024,t2-t1,1000*i*len(b)//1024//(t2-t1)))
  f.close()
  umount("/sd")
  i=0
  t1=ticks_ms()
  while i<256: 
    sd.readblocks(i,b)
    i+=1
  t2=ticks_ms()
  print("%d KB in %d ms => %d KB/s raw sector read" % (i*len(b)//1024,t2-t1,1000*i*len(b)//1024//(t2-t1)))
  sd.deinit()
run()
