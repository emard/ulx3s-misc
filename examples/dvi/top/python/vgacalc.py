#!/usr/bin/env python3

'''
  //  modes tested on lenovo monitor
  //  640x400  @50Hz
  //  640x400  @60Hz
  //  640x480  @50Hz
  //  640x480  @60Hz
  //  720x576  @50Hz
  //  720x576  @60Hz
  //  800x480  @60Hz
  //  800x600  @60Hz
  // 1024x768  @50Hz
  // 1024x768  @60Hz
  // 1280x768  @60Hz
  // 1366x768  @60Hz
  // 1280x1024 @60Hz
  // 1920x1080 @30Hz
  // 1920x1080 @50Hz overclock 540MHz
  // 1920x1200 @50Hz overclock 600MHz
'''

x = 1024;      # pixels
y =  768;      # pixels
f =   50;      # Hz 60,50,30
xadjustf =  0; # adjust -3..3 if no picture
yadjustf =  0; # or to fine-tune f
c_ddr    =  1; # 0:SDR 1:DDR

def F_find_next_f(f:int)->int:
    if(25000000>f):
      return 25000000;
    if(27000000>f):
      return 27000000;
    if(40000000>f):
      return 40000000;
    if(50000000>f):
      return 50000000;
    if(54000000>f):
      return 54000000;
    if(60000000>f):
      return 60000000;
    if(65000000>f):
      return 65000000;
    if(75000000>f):
      return 75000000;
    if(80000000>f):
      return 80000000;  # overclock
    if(100000000>f):
      return 100000000; # overclock
    if(108000000>f):
      return 108000000; # overclock
    if(120000000>f):
      return 120000000; # overclock

xminblank         = x//64; # initial estimate
yminblank         = y//64; # for minimal blank space
min_pixel_f       = f*(x+xminblank)*(y+yminblank);
pixel_f           = F_find_next_f(min_pixel_f);
yframe            = y+yminblank;
xframe            = pixel_f//(f*yframe);
xblank            = xframe-x;
yblank            = yframe-y;
hsync_front_porch = xblank//3;
hsync_pulse_width = xblank//3;
hsync_back_porch  = xblank-hsync_pulse_width-hsync_front_porch+xadjustf;
vsync_front_porch = yblank//3;
vsync_pulse_width = yblank//3;
vsync_back_porch  = yblank-vsync_pulse_width-vsync_front_porch+yadjustf;

print("x", x)
print("y", y)
print("f", f)
print("pixel_f", pixel_f)
print("hsync_front_porch", hsync_front_porch)
print("hsync_pulse_width", hsync_pulse_width)
print("hsync_back_porch",  hsync_back_porch)
print("vsync_front_porch", vsync_front_porch)
print("vsync_pulse_width", vsync_pulse_width)
print("vsync_back_porch",  vsync_back_porch)
