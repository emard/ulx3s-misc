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
// int seconds, doesn't handle 1/10 seconds
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

// from GPRMC nmea timedate
// to 22-byte len kml timestamp (23 bytes including null termination)
int nmea2kmltime(char *nmea, char *kml)
{
  char *b = nthchar(nmea, 9, ',');
  if (b == NULL)
    return 0;
  strcpy(kml, "2000-01-01T00:00:00.0Z");
  // position to date, nmea[7] is first char of time
  kml[ 2] = b[5]; // year/10
  kml[ 3] = b[6]; // year%10
  kml[ 5] = b[3]; // month/10
  kml[ 6] = b[4]; // month%10
  kml[ 8] = b[1]; // day/10
  kml[ 9] = b[2]; // day%10
  kml[11] = nmea[ 7]; // hour/10
  kml[12] = nmea[ 8]; // hour%10
  kml[14] = nmea[ 9]; // minute/10
  kml[15] = nmea[10]; // minute%10
  kml[17] = nmea[11]; // int(second)/10
  kml[18] = nmea[12]; // int(second)%10
  kml[20] = nmea[14]; // second*10%10 (1/10 seconds)
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

void latlon2float(struct int_latlon *latlon, float flatlon[])
{
  flatlon[0] = latlon->lat_deg + abs(latlon->lat_umin)*1.66666666e-8;
  if(latlon->lat_umin < 0)
    flatlon[0] = -flatlon[0];
  flatlon[1] = latlon->lon_deg + abs(latlon->lon_umin)*1.66666666e-8;
  if(latlon->lon_umin < 0)
    flatlon[1] = -flatlon[1];
}
