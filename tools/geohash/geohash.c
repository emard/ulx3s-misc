#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <fcntl.h>
#include <unistd.h>

#define hash_grid_spacing_m 32 // [m] steps power of 2
#define hash_grid_size 32 // N*N grid 32*32=1024
#define snap_point_max 8192 // total max snap points
int wr_snap_ptr = 0; // pointer to free snap point index
const int Rearth_m = 6378137; // [m] earth radius
// constants to convert lat,lon to grid index
int lat2grid,  lon2grid;
int lat2gridm, lon2gridm;

struct s_snap_point
{
  int32_t xm, ym;  // lat,lon converted to int meters (approx), int-search is faster than float
  int16_t next; // next snap point index
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
const int dlat2m = Rearth_m * M_PI / 180.0;

// conversion dlon to meters depends on lat
int dlon2m(int lat)
{
  return (int) (dlat2m * cos(lat * M_PI / 180.0));
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
    snap_point[i].next = -1; // -1 is empty, similar to null pointer
  wr_snap_ptr = 0;
}

int store_lon_lat(float lon, float lat)
{
  if(wr_snap_ptr >= snap_point_max)
    return 0;

  // convert lon,lat to int meters
  int xm = floor(lon * lon2gridm);
  int ym = floor(lat * lat2gridm);

  // snap int meters to grid 0
  uint8_t xgrid = (xm / hash_grid_spacing_m) & (hash_grid_size-1);
  uint8_t ygrid = (ym / hash_grid_spacing_m) & (hash_grid_size-1);

  snap_point[wr_snap_ptr].xm = xm;
  snap_point[wr_snap_ptr].ym = ym;

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
  for(i = 0; i < snap_point_max; i++)
    if(snap_point[i].next >= 0)
      printf("snap_point[%d].next=%d\n", i, snap_point[i].next);
}

int find_lon_lat(float lon, float lat)
{
  // convert lon,lat to int meters
  int xm = floor(lon * lon2gridm);
  int ym = floor(lat * lat2gridm);

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
  uint8_t i,j;
  int8_t x,y;
  for(i = 0, x = xgrid; i < 2; i++, x = (x+xs) & (hash_grid_size-1))
    for(j = 0, y = ygrid; j < 2; j++, y = (y+ys) & (hash_grid_size-1))
      // iterate to find closest element - least distance
      for(int16_t iter = hash_grid[x][y]; iter != -1; iter = snap_point[iter].next)
      {
        uint32_t new_dist = abs(snap_point[iter].xm - xm) + abs(snap_point[iter].ym - ym);
        if(new_dist < dist)
        {
          dist = new_dist;
          index = iter;
        }
      }
  return index;
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
      if(check_crc(nmea, nmea_len))
        printf("%s\n", nmea);
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
    int index = find_lon_lat(lon[i], lat[i]);
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
  if(argc > 1)
    wavreader(argv[1]);
}
