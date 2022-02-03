#include <stdint.h>
#include <stdlib.h>
#include "nmea.h"

#if 0
inline uint8_t hex2int(char a)
{
  return a <= '9' ? a-'0' : a-'A'+10;
}

int check_nmea_crc(char *a)
{
  if(a[0] != '$')
    return 0;
  uint8_t crc = 0;
  for(a++; a[0] != '\0' && a[0] != '*'; a++)
    crc ^= a[0];
  if(a[0] != '*')
    return 0;
  return crc == ( (hex2int(a[1])<<4) | hex2int(a[2]) );
}
#endif

#if 1
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
#endif

// parsing this will write null-delimiters into a
// so "a" will be broken afterwards
// negative microminutes mean S or W
void nmea2latlon(char *a, struct int_latlon *latlon)
{
  int umin;
  char a0,a1,a2; // preserve original values

  // read fractional minutes from back to top, null-terminating the string
  a2 = a[29];
  a[29] = 0; // replace ','->0
  umin  = strtol(a+23, NULL, 10);          // fractional minutes to microminutes
  a1 = a[22];
  a[22] = 0; // replace '.'->0
  umin += strtol(a+20, NULL, 10)*1000000;  // add integer minutes to microminutes
  a0 = a[20];
  a[20] = 0;
  latlon->lat_deg  = strtol(a+18, NULL, 10);
  if(a[30]=='S')
    umin = -umin;
  latlon->lat_umin = umin;
  // return original values
  a[29] = a2;
  a[22] = a1;
  a[20] = a0;

  a2 = a[44];
  a[44] = 0; // replace ','->0
  umin  = strtol(a+38, NULL, 10);          // fractional minutes to microminutes
  a1 = a[37];
  a[37] = 0; // replace '.'->0
  umin += strtol(a+35, NULL, 10)*1000000;  // add integer minutes to microminutes
  a0 = a[35];
  a[35] = 0;
  latlon->lon_deg  = strtol(a+32, NULL, 10);
  if(a[45]=='W')
    umin = -umin;
  latlon->lon_umin = umin;
  // return original values
  a[44] = a2;
  a[37] = a1;
  a[35] = a0;
}

uint16_t nmea2iheading(char *nmea)
{
  char *b = nthchar(nmea, 8, ','); // position to heading
  char str_heading[5] = "0000"; // storage for parsing
  str_heading[0] = b[1];
  str_heading[1] = b[2];
  str_heading[2] = b[3];
  str_heading[3] = b[5]; // skip b[4]=='.'
  //str_heading[4] = 0;
  uint16_t iheading = strtol(str_heading, NULL, 10); // parse as integer 0-360 -> 0-65536
  return iheading;
}

void latlon2float(struct int_latlon *latlon, float flatlon[])
{
  flatlon[0] = latlon->lat_deg + abs(latlon->lat_umin)*1.66666666e-8;
  if(latlon->lat_umin < 0)
    flatlon[0] = -flatlon[0];
  flatlon[1] = latlon->lon_deg + abs(latlon->lon_umin)*1.66666666e-8;
  if(latlon->lon_umin < 0)
    flatlon[1] = -flatlon[1];
}
