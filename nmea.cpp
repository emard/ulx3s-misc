// used to handle $GPRMC NMEA sentence
#include "nmea.h"
#include <string.h> // only for NULL pointer

// NMEA timestamp string (day time) from conversion factors to 10x seconds
uint32_t nmea2sx[8] = { 360000,36000,6000,600,100,10,0,1 };

// convert nmea daytime HHMMSS.S to seconds since midnight x10 (0.1 s resolution)
int nmea2s(char *nmea)
{
  int s = 0;
  for(int i = 0; i < 8; i++)
  s += (nmea[i]-'0')*nmea2sx[i];
  return s;
}

inline uint8_t hex2int(char a)
{
  return a <= '9' ? a-'0' : a-'A'+10;
}

int check_nmea_crc(char *a)
{
  int i;
  if(a[0] != '$')
    return 0;
  a++;
  uint8_t crc = 0;
  for(i = 1; a[0] != '\0' && a[0] != '*'; i++, a++)
    crc ^= a[0];
  if(a[0] != '*')
    return 0;
  return crc == ( (hex2int(a[1])<<4) | hex2int(a[2]) );
}

// find position of nth char (used as CSV parser)
char *nthchar(char *a, int n, char c)
{
  int i;
  for(i=0; *a; a++)
  {
    if(*a == c)
      i++;
    if(i == n)
      return a;
  }
  return NULL;
}
