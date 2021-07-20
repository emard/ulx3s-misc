#include <stdint.h>
#include <time.h>
int nmea2s(char *nmea);
int nmea2tm(char *a, struct tm *t);
inline uint8_t hex2int(char a);
uint8_t write_nmea_crc(char *a);
int check_nmea_crc(char *a);
char *nthchar(char *a, int n, char c);
