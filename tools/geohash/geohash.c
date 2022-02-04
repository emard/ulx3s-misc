#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include "nmea.h"
#include "kml.h"

#define snap_range_m 40 // [m] x+y < snap_range_m
#define hash_grid_spacing_m 64 // [m] steps power of 2 should be > snap_range_m
#define hash_grid_size 32 // N*N grid 32*32=1024
#define snap_point_max 8192 // total max snap points
int wr_snap_ptr = 0; // pointer to free snap point index
const int Rearth_m = 6378137; // [m] earth radius
// constants to convert lat,lon to grid index
int lat2grid,  lon2grid;  // to grid index
int lat2gridm, lon2gridm; // to [m] approx meters (for grid metric)
uint32_t found_dist; // hackish way

float last_latlon[2] = {46.0,16.0}; // stored previous value for travel calculation
int32_t travel_mm = 0;

struct s_snap_point
{
  int32_t xm, ym;  // lat,lon converted to int meters (approx), int-search is faster than float
  uint8_t n;       // number of measurements
  uint16_t heading; // [deg*65536/360] heading 0-65535 means 0-359.999 deg
  int16_t next;    // next snap point index
};

struct s_snap_point snap_point[snap_point_max];
int16_t hash_grid[hash_grid_size][hash_grid_size]; // 2 overlapping grids

float haversin(float theta)
{
  float s = sin(0.5*theta);
  return s*s;
}

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
void calculate_grid(int lat)
{
  lat2grid  = dlat2m      / hash_grid_spacing_m;
  lon2grid  = dlon2m(lat) / hash_grid_spacing_m;

  lat2gridm = dlat2m     ;
  lon2gridm = dlon2m(lat);
}

void reset_storage(void)
{
  int i, j;
  for(i = 0; i < hash_grid_size; i++)
    for(j = 0; j < hash_grid_size; j++)
      hash_grid[i][j] = -1; // -1 is empty, similar to null pointer
  for(i = 0; i < snap_point_max; i++)
  {
    snap_point[i].next = -1; // -1 is empty, similar to null pointer
    snap_point[i].n = 0; // stat counter
  }
  wr_snap_ptr = 0;
}

int store_lon_lat(float lon, float lat, float heading)
{
  if(wr_snap_ptr >= snap_point_max)
    return 0;

  // convert lon,lat to int meters
  int xm = floor(lon * lon2gridm);
  int ym = floor(lat * lat2gridm);
  uint16_t headin = floor(heading * (65536.0/360)); // heading angle

  // snap int meters to grid 0
  uint8_t xgrid = (xm / hash_grid_spacing_m) & (hash_grid_size-1);
  uint8_t ygrid = (ym / hash_grid_spacing_m) & (hash_grid_size-1);

  snap_point[wr_snap_ptr].xm = xm;
  snap_point[wr_snap_ptr].ym = ym;
  snap_point[wr_snap_ptr].heading = headin;

  int16_t saved_ptr;

  // grid insert element
  saved_ptr = hash_grid[xgrid][ygrid];
  hash_grid[xgrid][ygrid] = wr_snap_ptr;
  snap_point[wr_snap_ptr].next = saved_ptr;
  wr_snap_ptr++;

  return 1; // ok
}

void print_storage(void)
{
  int i, j;

  for(i = 0; i < hash_grid_size; i++)
    for(j = 0; j < hash_grid_size; j++)
      if(hash_grid[i][j] >= 0)
        printf("hash_grid[%d][%d]=%d\n", i, j, hash_grid[i][j]);
  for(i = 0; i < wr_snap_ptr; i++)
    if(snap_point[i].next >= 0)
      printf("snap_point[%d].next=%d\n", i, snap_point[i].next);
}

// write stored placemarks as kml arrows
void write_storage2kml(char *filename)
{
  int kmlf = open(filename, O_CREAT | O_TRUNC | O_WRONLY, 0644);
  kml_init();
  kml_header("name");
  write(kmlf, kmlbuf, strlen(kmlbuf));
  kml_buf_init();
  for(int i = 0; i < wr_snap_ptr; i++)
  {
    x_kml_arrow->lon       = (float)(snap_point[i].xm) / (float)lon2gridm;
    x_kml_arrow->lat       = (float)(snap_point[i].ym) / (float)lat2gridm;
    x_kml_arrow->value     = (float)(snap_point[i].n);
    x_kml_arrow->left      =  1.0;
    x_kml_arrow->right     =  1.0;
    x_kml_arrow->heading   = (float)(snap_point[i].heading * (360.0/65536));
    x_kml_arrow->speed_kmh = 80.0;
    x_kml_arrow->timestamp = "2000-01-01T00:00:00.0Z";
    kml_arrow(x_kml_arrow);
    write(kmlf, kmlbuf, str_kml_arrow_len);
  }
  write(kmlf, str_kml_footer_simple, strlen(str_kml_footer_simple));
  close(kmlf);
}

// 2D grid hash search
// x,y: integer grid coordinates, can represent anything but
//     here is used as approx meters
// convert lon,lat to int meters. lon2gridm, lat2gridm are constants
// int xm = floor(lon * lon2gridm);
// int ym = floor(lat * lat2gridm);
// a   angle 16-bit unsigned angular heading 0-255 -> 0-358 deg
// ais angle insensitivity 2^n 0:max sensitive, 16:insensitive
// x+y metric is applied to find closest point
// TODO x+y+a metric is applied to find closest point
int find_xya(int xm, int ym, uint16_t a, uint8_t ais)
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
      for(int16_t iter = hash_grid[x][y]; iter != -1; iter = snap_point[iter].next)
      {
        // last term with variable "a" is angular distance
        uint32_t new_dist = abs(snap_point[iter].xm - xm) + abs(snap_point[iter].ym - ym) + (abs(snap_point[iter].heading - a)>>ais);
        if(new_dist < dist)
        {
          dist = new_dist;
          found_dist = dist; // HACK
          index = iter;
        }
      }
  return index;
}


void nmea_proc(char *nmea, int nmea_len)
{
  static int16_t closest_index = -1;
  static int32_t prev_travel_mm = 0; // for new point
  static int32_t closest_found_dist = 999999; // [m] distance to previous found existing point
  static int32_t closest_found_travel_mm = 999999;
  static float  new_lat, new_lon;
  static int have_new = 0;
  // printf("%s\n", nmea);
  char *nf;
  struct int_latlon ilatlon;
  nf = nthchar(nmea, 2, ',');
  if(nf)
    if(nf[1]=='A') // A means valid signal (not in tunnel)
    {
      printf("%s\n", nmea);
      nmea2latlon(nmea, &ilatlon);
      float flatlon[2];
      latlon2float(&ilatlon, flatlon);
      uint16_t heading = (65536.0/3600)*nmea2iheading(nmea); // 0-3600 -> 0-65536
      uint32_t lon2mm = dlon2mm(flatlon[0]);
      uint32_t   dxmm = fabs(flatlon[1]-last_latlon[1]) *  lon2mm;
      uint32_t   dymm = fabs(flatlon[0]-last_latlon[0]) * dlat2mm;
      uint32_t   d_mm = sqrt(dxmm*dxmm + dymm*dymm);
      if(d_mm < 40000) // ignore too large jumps > 40m
      {
        travel_mm += d_mm;
        if(travel_mm > 80000) // at >80 m travel start searching for nearest snap points
        {
          // memorize last lat/lon when travel <= 100m
          // as the candidate for new snap point.
          // we assume we have got some new point here
          if(prev_travel_mm <= 100000)
          {
            new_lat = flatlon[0];
            new_lon = flatlon[1];
            have_new = 1; // updated until 100 m
          }
          prev_travel_mm = travel_mm;
          // continue search until travel 120 m for existing point if found.
          // if not found after 120 m, create new lat/lon snap point.
          int16_t index = find_xya((int)floor(flatlon[1] * lon2gridm), (int)floor(flatlon[0] * lat2gridm), heading, 8);
          if(index >= 0) // found something
          {
            if(found_dist < closest_found_dist)
            {
              closest_index = index;
              closest_found_travel_mm = travel_mm;
              closest_found_dist = found_dist; // metric that covers diamond shaped area x+y = const
            }
          }
          if(travel_mm > 120000) // at 120 m we have to decide, new or existing
          {
            if(closest_index >= 0 && closest_found_dist < snap_range_m) // x+y < snap_range_m [m]
            {
              // TODO update statistics at existing lon/lat
              travel_mm -= closest_found_travel_mm; // adjust travel to snapped point
              snap_point[closest_index].n++;
            }
            else // create new point
            {
              if(have_new) // don't store if we don't have new point
              {
                store_lon_lat(new_lon, new_lat, (float)heading * (360.0/65536));
                printf("new\n");
              }
              travel_mm -= 100000;
            }
            // reset values for new search
            closest_found_travel_mm = 0;
            closest_index = -1;
            closest_found_dist = 999999;
            have_new = 0;
          }
        }
        
      }
      printf("%.6f° %.6f° travel=%d m\n", flatlon[0], flatlon[1], travel_mm/1000);
      last_latlon[0] = flatlon[0];
      last_latlon[1] = flatlon[1];
    }
}

// 0: crc bad
// 1: crc ok
int check_crc(char *nmea, int len)
{
  uint8_t crc = strtoul(nmea+len-2, NULL, 16);
  for(int i = 1; i < len-3; i++)
    crc ^= *(++nmea);
  return crc == 0 ? 1 : 0;
}

void wavreader(char *filename)
{
  int f = open(filename, O_RDONLY);
  lseek(f, 44, SEEK_SET);
  int16_t b[6];
  char a,c;
  char nmea[256];
  int nmea_len=0;

  for(;;)
  {
    if(read(f, b, sizeof(b)) != sizeof(b))
      break; // eof
    a = b[0]&1 | ((b[1]&1)<<1) | ((b[2]&1)<<2) | ((b[3]&1)<<3) | ((b[4]&1)<<4) | ((b[5]&1)<<5);
    if(a != 32 && a != 33)
    {
      c = a;
      if((a & 0x20) == 0)
        c ^= 0x40;
      if(nmea_len < sizeof(nmea)-2)
        nmea[nmea_len++] = c;
    }
    if(a == 32 && nmea_len > 3)
    {
      nmea[nmea_len] = 0;
      if(nmea[0] == '$')
        if(check_crc(nmea, nmea_len))
          nmea_proc(nmea, nmea_len);
      nmea_len = 0;
    }
  }
  close(f);
}

int main(int argc, char *argv[])
{
  float lat1, lon1, lat2, lon2, dlat, dlon;

  lat1=46.000; lon1=16.000;
  lat2=46.001; lon2=16.000;
  dlat = lat2-lat1;
  printf("lat1=%.6f° lon1=%.6f° lat2=%.6f° lon2=%.6f° dist=%.1fm\n",
    lat1, lon1, lat2, lon2, distance(lat1, lon1, lat2, lon2));
  printf("dlat=%.6f° dist=%.1fm\n",
    dlat, dlat*dlat2m);

  lat1=46.000; lon1=16.000;
  lat2=46.000; lon2=16.001;
  dlon = lon2-lon1;
  printf("lat1=%.6f° lon1=%.6f° lat2=%.6f° lon2=%.6f° dist=%.1fm\n",
    lat1, lon1, lat2, lon2, distance(lat1, lon1, lat2, lon2));
  printf("dlon=%.6f° dist=%.1fm\n",
    dlon, dlon*dlon2m(lat1));

  lon1=16.001; lat1=46.001;
  calculate_grid(lat1);
  printf("lon2grid=%d lat2grid=%d\n", lon2grid, lat2grid);
  int xgrid = lon1*lon2grid;
  int ygrid = lat1*lat2grid;
  int exgrid = ((int)(lon1*lon2gridm)) & (hash_grid_spacing_m-1);
  int eygrid = ((int)(lat1*lat2gridm)) & (hash_grid_spacing_m-1);
  printf("lon1=%.6f° lat1=%.6f° -> grid x,y = %d,%d -> hash x,y = %d,%d -> edge x,y = %d,%d\n",
    lon1, lat1, xgrid, ygrid, xgrid&31, ygrid&31, exgrid, eygrid);
  reset_storage();
  #if 0
  // debug code to test storage
  store_lon_lat(16.0000, 46.0000);
  store_lon_lat(16.0001, 46.0000);
  store_lon_lat(16.0000, 46.0001);
  store_lon_lat(16.0001, 46.0001);
  store_lon_lat(15.9997, 45.9996);
  print_storage();
  float lon[] = { 16.0000, 16.0001, 16.0000, 16.0001, 16.0002, 16.0002, 16.0000, 15.9999, 15.9998 };
  float lat[] = { 46.0000, 46.0000, 46.0001, 46.0001, 46.0002, 45.9999, 45.9999, 45.9999, 45.9996 };
  for(int i = 0; i < sizeof(lon)/sizeof(lon[0]); i++)
  {
    int index = find_xya(floor(lon[i] * lon2gridm), floor(lat[i] * lat2gridm), 0, 0);
    if(index != -1)
    {
      lon2 = (float)snap_point[index].xm / (float)lon2gridm;
      lat2 = (float)snap_point[index].ym / (float)lat2gridm;
      float dist = distance(lat[i], lon[i], lat2, lon2);
      printf("find lon=%.6f° lat=%.6f° lon2=%.6f° lat2=%.6f° -> %d -> dist=%.1f\n",
        lon[i], lat[i], lon2, lat2, index, dist);
    }
    else
      printf("find lon=%.6f° lat=%.6f° -> %d\n", lon[i], lat[i], index);
  }
  #endif
  for(int i = 1; i < argc; i++)
    wavreader(argv[i]);
  print_storage();
  write_storage2kml("/tmp/circle.kml");
}
