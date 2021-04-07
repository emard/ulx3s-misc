#include <stdint.h>
int nmea2s(char *nmea);
inline uint8_t hex2int(char a);
int check_nmea_crc(char *a);
char *nthchar(char *a, int n, char c);
