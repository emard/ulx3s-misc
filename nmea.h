#ifndef NMEA_H
#define NMEA_H
#include <stdint.h>
#include <time.h>
struct int_latlon
{
  int lat_deg, lat_umin, lon_deg, lon_umin;
};
int nmea2s(char *nmea);
int nmea2tm(char *a, struct tm *t);
void nmea2latlon(char *a, struct int_latlon *latlon);
inline uint8_t hex2int(char a);
uint8_t write_nmea_crc(char *a);
int check_nmea_crc(char *a);
char *nthchar(char *a, int n, char c);
#endif
