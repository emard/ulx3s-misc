#include <stdint.h>
int nmea2s(char *nmea);
inline uint8_t hex2int(char a);
uint8_t write_nmea_crc(char *a);
int check_nmea_crc(char *a);
char *nthchar(char *a, int n, char c);
