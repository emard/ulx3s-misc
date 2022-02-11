#ifndef GEOSTAT_H
#define GEOSTAT_H

#include <stdint.h>

// try to snap at segment length 100 m
#define SEGMENT_LENGTH_MM 100000

// angular insensitivity, scale factor to compare
// angle with maters
// angle 0-359.999 is converted to 16-bit 0-65535,
// right-shifted by this specified value and added
// added as matric expression
// abs(x1-x0)+abs(y1-y0)+abs(a1-a0)
#define ANGULAR_INSENSITIVITY_RSHIFT 8

#define SNAP_RANGE_M 40 // [m] x+y < snap_range_m search for existing point

// after this length decide how to snap, new or existing point
// decide usually at 120 m if snap length is 100 m
#define SNAP_DECISION_MM (SEGMENT_LENGTH_MM+20000)

// reverse alignment: allowed range usually +-5m from snap legnth
#define ALIGN_TO_REVERSE_MIN_MM (SEGMENT_LENGTH_MM-5000)
#define ALIGN_TO_REVERSE_MAX_MM (SEGMENT_LENGTH_MM+5000)

// ignore this point if distance from prev reading to current reading 
// is more than this length apart 
#define IGNORE_TOO_LARGE_JUMP_MM 40000

// after this travel length start searching for snap point
#define START_SEARCH_FOR_SNAP_POINT_AFTER_TRAVEL_MM 40000

// hash grid parameters
#define hash_grid_spacing_m 64 // [m] steps power of 2 should be > snap_range_m
#define hash_grid_size 32 // N*N grid 32*32=1024
#define snap_point_max 1900 // total max snap points

//extern int wr_snap_ptr;
extern int lat2grid,  lon2grid;
extern int lat2gridm, lon2gridm;
//extern uint32_t found_dist;
//extern float last_latlon[];
//extern int32_t travel_mm;
extern const int dlat2m;
extern const uint32_t dlat2mm;

struct s_snap_point
{
  int32_t xm, ym;  // lat,lon converted to int meters (approx), int-search is faster than float
  uint8_t n;       // number of measurements
  uint16_t heading; // [deg*65536/360] heading 0-65535 means 0-359.999 deg
  float sum_iri[2][2]; // [0:normal, 1:squares][0:left, 1:right]
  int16_t next;    // next snap point index
};

extern int wr_snap_ptr; // pointer to free snap point index
extern int16_t hash_grid[hash_grid_size][hash_grid_size];
extern struct s_snap_point snap_point[snap_point_max];

float haversin(float theta);
float distance(float lat1, float lon1, float lat2, float lon2);
int dlon2m(int lat);
uint32_t dlon2mm(float lat);
void calculate_grid(int lat);
void clear_storage(void);
int store_lon_lat(float lon, float lat, float heading);
void print_storage(void);
int find_xya(int xm, int ym, uint16_t a, uint8_t ais);
void stat_iri_proc(char *nmea, int nmea_len);
void stat_nmea_proc(char *nmea, int nmea_len);
int check_crc(char *nmea, int len);

#endif
