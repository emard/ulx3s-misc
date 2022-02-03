#ifndef NMEA_H
#define NMEA_H
#include <stdint.h>
#include <time.h>
struct int_latlon
{
  int lat_deg, lat_umin, lon_deg, lon_umin;
};
void nmea2latlon(char *a, struct int_latlon *latlon);
void latlon2float(struct int_latlon *latlon, float flatlon[]);
int check_nmea_crc(char *a);
char *nthchar(char *a, int n, char c);
uint16_t nmea2iheading(char *nmea);
#endif
