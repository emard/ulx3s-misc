#include <stdio.h>
#include <stdint.h>

int32_t pos = 0;
int32_t spd = 277;

int main(int argc, char *argv[])
{
  int32_t i, spd_min = 0, spd_max = 0, pos_min = 9990, pos_max = 0;
  int32_t pos_u;

  for(i = 0; i < 10000; i++)
  {
    pos += spd/8;
    spd -= pos/256;
    
    //pos_u = (pos ^ 0xFFFFF800) & 0xFFF;
    pos_u = pos;
    //pos_u = (pos ^ 0x7FF) & 0xFFF;
    if(pos_u > pos_max) pos_max = pos_u;
    if(pos_u < pos_min) pos_min = pos_u;
    if(spd > spd_max) spd_max = spd;
    if(spd < spd_min) spd_min = spd;
#if 0
    printf("pos=%d spd=%d\n", pos_u, spd);
#endif
  }
  printf("pos=%d..%d spd=%d..%d\n", pos_min, pos_max, spd_min, spd_max);

}