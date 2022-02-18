#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include "nmea.h"
#include "kml.h"
#include "geostat.h"
#include "sdcard.h" // for iri[] only

struct s_stat s_stat; // about 40KB statistics for kml "arrows"

//int wr_snap_ptr = 0; // pointer to free snap point index
// constants to convert lat,lon to grid index
int lat2grid,  lon2grid;  // to grid index
int lat2gridm, lon2gridm; // to [m] approx meters (for grid metric)
uint32_t found_dist; // HACKish use

float stat_travel_prev_latlon[2] = {46.0,16.0}; // stored previous value for travel calculation
int32_t stat_travel_mm = 0;
uint8_t round_count = 1;
uint8_t stat_speed_kmh = 80;

extern int daytime; // from main module

// #define PARSED_IRI
#if PARSED_IRI
float parsed_iri[2][2]; // iri parsed from wav tags
#endif

float haversin(float theta)
{
  float s = sin(0.5*theta);
  return s*s;
};

const int Rearth_m = 6378137; // [m] earth radius

// formula to check distance
// input lat/lon in degrees
// return distance in meters
float distance(float lat1, float lon1, float lat2, float lon2)
{
  // convert to radians
  lat1 *= M_PI/180.0;
  lon1 *= M_PI/180.0;
  lat2 *= M_PI/180.0;
  lon2 *= M_PI/180.0;
  float deltalat=lat2-lat1;
  float deltalon=lon2-lon1;
  float h=haversin(deltalat)+cosf(lat1)*cosf(lat2)*haversin(deltalon);
  float dist=2*Rearth_m*asinf(sqrt(h));
  return dist;
}

// conversion dlat to meters is constant for every lon
const int dlat2m  = Rearth_m * M_PI / 180.0;

// conversion dlon to meters depends on lat
int dlon2m(int lat)
{
  return (int) (dlat2m * cos(lat * M_PI / 180.0));
}

// conversion dlat to millimeters is constant for every lon
const uint32_t dlat2mm = Rearth_m * 1000.0 * M_PI / 180.0;

// conversion dlon to millimeters depends on lat
uint32_t dlon2mm(float lat)
{
  return dlat2mm * cos(lat * M_PI / 180.0);
}

// for lat calculate constants
// to convert deg to int grid array index
// call this once per session
// changing lat will slightly distort grid but
// for hashing it doesn't matter much
void calculate_grid(int8_t lat)
{
  lat2grid  = dlat2m      / hash_grid_spacing_m;
  lon2grid  = dlon2m(lat) / hash_grid_spacing_m;

  lat2gridm = dlat2m     ;
  lon2gridm = dlon2m(lat);

  s_stat.lat = lat;
}

void clear_storage(void)
{
  int i, j;
  for(i = 0; i < hash_grid_size; i++)
    for(j = 0; j < hash_grid_size; j++)
      s_stat.hash_grid[i][j] = -1; // -1 is empty, similar to null pointer
  for(i = 0; i < snap_point_max; i++)
  {
    s_stat.snap_point[i].next = -1; // -1 is empty, similar to null pointer
    s_stat.snap_point[i].n = 0; // stat counter
  }
  s_stat.wr_snap_ptr = 0;
  stat_travel_mm = 0;
  round_count = 1;
}

// retval
// index of stored element
// -1 out of memory
int store_lon_lat(float lon, float lat, float heading)
{
  if(s_stat.wr_snap_ptr >= snap_point_max)
    return -1; // out of memory

  // convert lon,lat to int meters
  int xm = floor(lon * lon2gridm);
  int ym = floor(lat * lat2gridm);
  uint8_t headin = floor(heading * (256.0/360)); // heading angle

  // snap int meters to grid 0
  uint8_t xgrid = (xm / hash_grid_spacing_m) & (hash_grid_size-1);
  uint8_t ygrid = (ym / hash_grid_spacing_m) & (hash_grid_size-1);

  s_stat.snap_point[s_stat.wr_snap_ptr].xm = xm;
  s_stat.snap_point[s_stat.wr_snap_ptr].ym = ym;
  s_stat.snap_point[s_stat.wr_snap_ptr].heading = headin;

  int16_t saved_ptr;

  // grid insert element
  saved_ptr = s_stat.hash_grid[xgrid][ygrid];
  s_stat.hash_grid[xgrid][ygrid] = s_stat.wr_snap_ptr;
  s_stat.snap_point[s_stat.wr_snap_ptr].next = saved_ptr;
  return s_stat.wr_snap_ptr++;
}

void print_storage(void)
{
  int i, j;

  for(i = 0; i < hash_grid_size; i++)
    for(j = 0; j < hash_grid_size; j++)
      if(s_stat.hash_grid[i][j] >= 0)
        printf("hash_grid[%d][%d]=%d\n", i, j, s_stat.hash_grid[i][j]);
  for(i = 0; i < s_stat.wr_snap_ptr; i++)
    if(s_stat.snap_point[i].next >= 0)
      printf("snap_point[%d].next=%d\n", i, s_stat.snap_point[i].next);
}

// 2D grid hash search
// x,y: integer grid coordinates, can represent anything but
//     here is used as approx meters
// convert lon,lat to int meters. lon2gridm, lat2gridm are constants
// int xm = floor(lon * lon2gridm);
// int ym = floor(lat * lat2gridm);
// a   angle 8-bit unsigned angular heading 0-255 -> 0-358 deg
// ais angle insensitivity 2^n 0:max sensitive, 8:insensitive
// x+y metric is applied to find closest point
// TODO x+y+a metric is applied to find closest point
int find_xya(int xm, int ym, uint8_t a, uint8_t ais)
{
  // snap int meters to grid 0
  uint8_t xgrid = (xm / hash_grid_spacing_m) & (hash_grid_size-1);
  uint8_t ygrid = (ym / hash_grid_spacing_m) & (hash_grid_size-1);
  // position in quadrant for edge selection
  uint8_t xq = xm & (hash_grid_spacing_m-1);
  uint8_t yq = ym & (hash_grid_spacing_m-1);
  // 2x2 search step for adjacent quadrants
  int8_t xs = xq >= hash_grid_spacing_m/2 ? 1 : -1;
  int8_t ys = yq >= hash_grid_spacing_m/2 ? 1 : -1;
  //printf("xgrid=%d, ygrid=%d, xs=%d, ys=%d\n", xgrid, ygrid, xs, ys);
  // in 2x2 adjacent quadrants find least distance
  int16_t index = -1;
  uint32_t dist = 999999; // some large value
  found_dist = dist; // HACK
  uint8_t i,j;
  int8_t x,y;
  for(i = 0, x = xgrid; i < 2; i++, x = (x+xs) & (hash_grid_size-1))
    for(j = 0, y = ygrid; j < 2; j++, y = (y+ys) & (hash_grid_size-1))
      // iterate to find closest element - least distance
      for(int16_t iter = s_stat.hash_grid[x][y]; iter != -1; iter = s_stat.snap_point[iter].next)
      {
        int8_t angular_distance = s_stat.snap_point[iter].heading - a;
        uint32_t new_dist = abs(s_stat.snap_point[iter].xm - xm) + abs(s_stat.snap_point[iter].ym - ym) + (abs(angular_distance)>>ais);
        if(new_dist < dist)
        {
          dist = new_dist;
          found_dist = dist; // HACK
          index = iter;
        }
      }
  return index;
}

#if PARSED_IRI
// 01234567890123
// L01.00R01.20*AB
void stat_iri_proc(char *nmea, int nmea_len)
{
  if(nmea[0]=='L' && nmea[6]=='R') // detects IRI-100
  {
    parsed_iri[0][0] = atof(nmea+1);
    parsed_iri[1][0] = parsed_iri[0][0] * parsed_iri[0][0]; // square
    parsed_iri[0][1] = atof(nmea+7);
    parsed_iri[1][1] = parsed_iri[0][1] * parsed_iri[0][1]; // square
  }
}
#endif

void stat_nmea_proc(char *nmea, int nmea_len)
{
  static int16_t closest_index = -1;
  static int32_t prev_stat_travel_mm = 0; // for new point
  static int32_t closest_found_dist = 999999; // [m] distance to previous found existing point
  static int32_t closest_found_stat_travel_mm = 999999;
  static float  new_lat, new_lon;
  static uint8_t new_heading;
  static uint16_t new_daytime;
  static float new_iri[2], closest_iri[2];
  static uint8_t new_kmh, closest_kmh;
  static int have_new = 0;
  // printf("%s\n", nmea);
  char *nf;
  struct int_latlon ilatlon;
  nf = nthchar(nmea, 2, ',');
  if(nf)
    if(nf[1]=='A') // A means valid signal (not in tunnel)
    {
      //printf("%s\n", nmea);
      nmea2latlon(nmea, &ilatlon);
      float flatlon[2];
      latlon2float(&ilatlon, flatlon);
      uint8_t heading = (256.0/3600)*nmea2iheading(nmea); // 0-3600 -> 0-256
      uint32_t lon2mm = dlon2mm(flatlon[0]);
      uint32_t   dxmm = fabs(flatlon[1]-stat_travel_prev_latlon[1]) *  lon2mm;
      uint32_t   dymm = fabs(flatlon[0]-stat_travel_prev_latlon[0]) * dlat2mm;
      uint32_t   d_mm = sqrt(dxmm*dxmm + dymm*dymm);
      if(d_mm < IGNORE_TOO_LARGE_JUMP_MM) // ignore too large jumps > 40m
      {
        stat_travel_mm += d_mm;
        if(stat_travel_mm > START_SEARCH_FOR_SNAP_POINT_AFTER_TRAVEL_MM) // at >40 m travel start searching for nearest snap points
        {
          // memorize last lat/lon when travel <= 100m
          // as the candidate for new snap point.
          // we assume we have got some new point here
          if(prev_stat_travel_mm <= SEGMENT_LENGTH_MM)
          {
            new_lat = flatlon[0];
            new_lon = flatlon[1];
            new_heading = heading;
            new_daytime = daytime/20; // new_daytime is in 2-second ticks 0-43199
            new_iri[0] = iri[0];
            new_iri[1] = iri[1];
            new_kmh = stat_speed_kmh;
            have_new = 1; // updated until 100 m
          }
          prev_stat_travel_mm = stat_travel_mm;
          // continue search until travel 120 m for existing point if found.
          // if not found after 120 m, create new lat/lon snap point.
          // angular insensitivty 0, means 256 is 360 deg, and to add 128 m for 180 deg reverse direction snap point
          int16_t index = find_xya((int)floor(flatlon[1] * lon2gridm), (int)floor(flatlon[0] * lat2gridm), heading, ANGULAR_INSENSITIVITY_RSHIFT);
          if(index >= 0) // found something
          {
            if(found_dist < closest_found_dist)
            {
              closest_index = index;
              closest_found_stat_travel_mm = stat_travel_mm;
              closest_found_dist = found_dist; // [m] metric that covers diamond shaped area x+y = const
              closest_iri[0] = iri[0];
              closest_iri[1] = iri[1];
              closest_kmh = stat_speed_kmh;
            }
          }
          if(stat_travel_mm > SNAP_DECISION_MM) // at 120 m we have to decide, new or existing
          {
            if(closest_index >= 0 && closest_found_dist < SNAP_RANGE_M) // x+y < SNAP_RANGE_M [m]
            {
              // TODO update statistics at existing lon/lat
              stat_travel_mm -= closest_found_stat_travel_mm; // adjust travel to snapped point
              s_stat.snap_point[closest_index].n++;
              round_count = s_stat.snap_point[closest_index].n;
              s_stat.snap_point[closest_index].sum_iri[0][0] += closest_iri[0];
              s_stat.snap_point[closest_index].sum_iri[0][1] += closest_iri[1];
              s_stat.snap_point[closest_index].sum_iri[1][0] += closest_iri[0]*closest_iri[0];
              s_stat.snap_point[closest_index].sum_iri[1][1] += closest_iri[1]*closest_iri[1];
              if(closest_kmh < s_stat.snap_point[closest_index].vmin)
                s_stat.snap_point[closest_index].vmin = closest_kmh;
              if(closest_kmh > s_stat.snap_point[closest_index].vmax)
                s_stat.snap_point[closest_index].vmax = closest_kmh;
            }
            else // create new point
            {
              if(have_new) // don't store if we don't have new point
              {
                int new_index = store_lon_lat(new_lon, new_lat, (float)new_heading * (360.0/256));
                if(new_index >= 0)
                {
                  s_stat.snap_point[new_index].n = 1;
                  round_count = 1;
                  s_stat.snap_point[new_index].sum_iri[0][0] = new_iri[0];
                  s_stat.snap_point[new_index].sum_iri[0][1] = new_iri[1];
                  s_stat.snap_point[new_index].sum_iri[1][0] = new_iri[0]*new_iri[0];
                  s_stat.snap_point[new_index].sum_iri[1][1] = new_iri[1]*new_iri[1];
                  s_stat.snap_point[new_index].daytime = new_daytime;
                  // set initial speed, informative only
                  s_stat.snap_point[new_index].vmin = s_stat.snap_point[new_index].vmax = new_kmh;
                }
                //printf("new\n");
              }
              if(closest_index >= 0 
              && closest_found_stat_travel_mm > ALIGN_TO_REVERSE_MIN_MM  // aligns to points in reverse direction
              && closest_found_stat_travel_mm < ALIGN_TO_REVERSE_MAX_MM) // in range 95-105 m 
                stat_travel_mm -= closest_found_stat_travel_mm; // tries to align with reverse direction snap point
              else
                stat_travel_mm -= SEGMENT_LENGTH_MM;
            }
            // reset values for new search
            closest_found_stat_travel_mm = 0;
            closest_index = -1;
            closest_found_dist = 999999;
            have_new = 0;
          }
        }
        
      }
      // printf("%.6f° %.6f° travel=%d m\n", flatlon[0], flatlon[1], stat_travel_mm/1000);
      stat_travel_prev_latlon[0] = flatlon[0];
      stat_travel_prev_latlon[1] = flatlon[1];
    }
}

// 0: crc bad
// 1: crc ok
int check_crc(char *nmea, int len)
{
  if(nmea[len-3]!='*')
    return 0;
  uint8_t crc = strtoul(nmea+len-2, NULL, 16);
  for(int i = 1; i < len-3; i++)
    crc ^= *(++nmea);
  return crc == 0 ? 1 : 0;
}
