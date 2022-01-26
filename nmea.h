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
int nmea2kmltime(char *nmea, char *kml);
void nmea2latlon(char *a, struct int_latlon *latlon);
void latlon2float(struct int_latlon *latlon, float flatlon[]);
inline uint8_t hex2int(char a);
uint8_t write_nmea_crc(char *a);
int check_nmea_crc(char *a);
char *nthchar(char *a, int n, char c);
#endif
