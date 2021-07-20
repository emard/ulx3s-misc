// used to handle $GPRMC NMEA sentence
#include "nmea.h"
#include <string.h> // only for NULL pointer
#include <stdlib.h> // strtol

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

// parse NMEA ascii string -> write to struct tm
int nmea2tm(char *a, struct tm *t)
{
  char *b = nthchar(a, 9, ',');
  if (b == NULL)
    return 0;
  t->tm_year  = (b[ 5] - '0') * 10 + (b[ 6] - '0') + 100;
  t->tm_mon   = (b[ 3] - '0') * 10 + (b[ 4] - '0') - 1;
  t->tm_mday  = (b[ 1] - '0') * 10 + (b[ 2] - '0');
  t->tm_hour  = (a[ 7] - '0') * 10 + (a[ 8] - '0');
  t->tm_min   = (a[ 9] - '0') * 10 + (a[10] - '0');
  t->tm_sec   = (a[11] - '0') * 10 + (a[12] - '0');
  return 1;
}

inline uint8_t hex2int(char a)
{
  return a <= '9' ? a-'0' : a-'A'+10;
}

inline void int2hex(uint8_t i, char *a)
{
  uint8_t nib = i >> 4;
  a[0] = nib < 10 ? '0'+nib : 'A'+nib-10;
  nib = i & 15;
  a[1] = nib < 10 ? '0'+nib : 'A'+nib-10;
}

// write crc as 2 hex digits after '*'
// return crc
uint8_t write_nmea_crc(char *a)
{
  uint8_t crc = 0;
  for(a++; a[0] != '\0' && a[0] != '*'; a++)
    crc ^= a[0];
  if(a[0] != '*')
    return crc;
  int2hex(crc, a+1);
  return crc;
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

// parsing this will write null-delimiters into a
// so "a" will be broken afterwards
// TODO N-S E-W is not handled yet, N E assumed
void nmea2latlon(char *a, struct int_latlon *latlon)
{
  int umin;

  // read fractional minutes from back to top, null-terminating the string
  a[29] = 0; // replace ','->0
  umin  = strtol(a+23, NULL, 10);          // fractional minutes to microminutes
  a[22] = 0; // replace '.'->0
  umin += strtol(a+20, NULL, 10)*1000000;  // add integer minutes to microminutes
  a[20] = 0;
  latlon->lat_deg  = strtol(a+18, NULL, 10);
  latlon->lat_umin = umin;

  a[44] = 0; // replace ','->0
  umin  = strtol(a+38, NULL, 10);          // fractional minutes to microminutes
  a[37] = 0; // replace '.'->0
  umin += strtol(a+35, NULL, 10)*1000000;  // add integer minutes to microminutes
  a[35] = 0;
  latlon->lon_deg  = strtol(a+32, NULL, 10);
  latlon->lon_umin = umin;
}
