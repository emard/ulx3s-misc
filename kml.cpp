#include <stdio.h>
#include <stdint.h> // uint32_t etc
#include <string.h>
#include <stdlib.h> // abs
#include "kml.h"
#include "nmea.h"

/*
longitude -180..180 (x-direction, EW)
latitude   -90..90  (y-direction, NS)
heading      0..360
*/

char kmlbuf[8192]; // 4-8K for write efficiency
int kmlbuf_start = 0; // start write from this, if arrow start from 0, or len to skip arrow
int kmlbuf_len = 0; // max write position
int kmlbuf_pos = 0; // current write position
uint8_t kmlbuf_has_arrow = 0;
float red_iri = 2.5;

struct s_kml_arrow x_kml_arrow[1];
struct s_kml_line  x_kml_line[1];

#if 0
void kml_open(void)
{
//  fkml = fopen("/tmp/demo.kml", "wb");
}
#endif

const char *str_kml_header = "\
<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n\
  <Document id=\"docid\">\n\
    <name>%22s</name>\n\
    <description>\
<![CDATA[\n\
Speed-time 100 m segment cuts with statistics.<br/>\n\
Click any point on the track to display mm/m value of a 100 m\n\
segment measured before the point. Value represents average\n\
rectified speed in the shock absorber over 100 m segment\n\
and divided by standard speed of 80 km/h. Value comes from the\n\
numeric model that calculates response at standard speed,\n\
removing dependency on actual speed at which measurement has been done.<br/>\n\
<br/>\n\
Color codes: \
<font color=\"red\">%.1f</font>, <font color=\"orange\">%.1f</font>, <font color=\"green\">%.1f</font>, <font color=\"cyan\">%.1f</font>, \
<font color=\"blue\">%.1f</font>, <font color=\"violet\">%.1f</font>, <font color=\"magenta\">0.0</font><br/>\n\
<br/>\n\
Click arrow to display statistics as<br/>\n\
average ± uncertainty<br/>\n\
where \"uncertainty\" represents 2σ = 96%% coverage.\n\
]]>\n\
    </description>\n\
    <visibility>1</visibility>\n\
    <Folder id=\"folderid\">\n\
      <name>Recorded data</name>\n\
      <description>onboard kml generator</description>\n\
      <visibility>1</visibility>\n\
";

const char *str_kml_line = "\
      <Placemark id=\"id\">\n\
        <name>NAME5</name>\n\
        <description>\
L20=L_20_ mm/m\n\
R20=R_20_ mm/m\n\
L100=L_100 mm/m\n\
R100=R_100 mm/m\n\
v=SPEED km/h\n\
TIMEDESCR0123456789012\n\
        </description>\n\
        <visibility>1</visibility>\n\
        <Style>\n\
          <LineStyle>\n\
            <color>COLOR678</color>\n\
            <width>6</width>\n\
          </LineStyle>\n\
        </Style>\n\
        <TimeStamp>\n\
          <when>TIMESTAMP0123456789012</when>\n\
        </TimeStamp>\n\
        <LineString>\n\
          <coordinates>LONLAT789012345678901234567890123456789012345</coordinates>\n\
        </LineString>\n\
      </Placemark>\n\
";
int str_kml_line_pos_lonlat;
int str_kml_line_pos_time;
int str_kml_line_pos_timed;
int str_kml_line_pos_speed;
int str_kml_line_pos_name;
int str_kml_line_pos_left20;
int str_kml_line_pos_right20;
int str_kml_line_pos_left100;
int str_kml_line_pos_right100;
int str_kml_line_pos_color;
int str_kml_line_len;

const char *str_kml_arrow = "\
      <Placemark id=\"id\">\n\
        <name>NAME5</name>\n\
        <description>\
L100=LEFT5 ± LSTDV mm/m\n\
R100=RIGHT ± RSTDV mm/m\n\
n=NM \n\
v=SPL-SPH km/h\n\
        </description>\n\
        <visibility>1</visibility>\n\
        <Style>\n\
          <IconStyle id=\"id\">\n\
            <color>COLOR678</color>\n\
            <scale>1.0</scale>\n\
            <heading>HEAD5</heading>\n\
            <Icon>\n\
              <href>http://maps.google.com/mapfiles/kml/shapes/arrow.png</href>\n\
            </Icon>\n\
          </IconStyle>\n\
        </Style>\n\
        <TimeStamp>\n\
          <when>TIMESTAMP0123456789012</when>\n\
        </TimeStamp>\n\
        <Point>\n\
          <coordinates>LONLAT7890123456789012</coordinates>\n\
        </Point>\n\
      </Placemark>\n\
";
int str_kml_arrow_pos_lonlat;
int str_kml_arrow_pos_heading;
int str_kml_arrow_pos_time;
int str_kml_arrow_pos_speed_min;
int str_kml_arrow_pos_speed_max;
int str_kml_arrow_pos_name;
int str_kml_arrow_pos_left;
int str_kml_arrow_pos_left_stdev;
int str_kml_arrow_pos_right;
int str_kml_arrow_pos_right_stdev;
int str_kml_arrow_pos_n;
int str_kml_arrow_pos_color;
int str_kml_arrow_len;

const char *str_kml_footer = "\
    </Folder>\n\
    <LookAt>\n\
      <longitude>LONGITUDE01</longitude>\n\
      <latitude>LATITUDE90</latitude>\n\
      <heading>HEAD5</heading>\n\
      <tilt>0</tilt>\n\
      <range>2000</range>\n\
      <altitudeMode>relativeToGround</altitudeMode>\n\
      <TimeSpan>\n\
        <begin>TIMEBEGIN9012345678901</begin>\n\
        <end>TIMEEND789012345678901</end>\n\
      </TimeSpan>\n\
    </LookAt>\n\
  </Document>\n\
</kml>\n\
";
int str_kml_footer_pos_longitude;
int str_kml_footer_pos_latitude;
int str_kml_footer_pos_heading;
int str_kml_footer_pos_begin;
int str_kml_footer_pos_end;
int str_kml_footer_len;

// simple constant footer, no LookAt
const char *str_kml_footer_simple = "\
    </Folder>\n\
  </Document>\n\
</kml>\n\
";
int str_kml_footer_simple_len;

void kml_init(void)
{
  str_kml_line_pos_lonlat      = strstr(str_kml_line, "LONLAT"    ) - str_kml_line;
  str_kml_line_pos_name        = strstr(str_kml_line, "NAME"      ) - str_kml_line;
  str_kml_line_pos_left20      = strstr(str_kml_line, "L_20"      ) - str_kml_line;
  str_kml_line_pos_right20     = strstr(str_kml_line, "R_20"      ) - str_kml_line;
  str_kml_line_pos_left100     = strstr(str_kml_line, "L_100"     ) - str_kml_line;
  str_kml_line_pos_right100    = strstr(str_kml_line, "R_100"     ) - str_kml_line;
  str_kml_line_pos_speed       = strstr(str_kml_line, "SPEED"     ) - str_kml_line;
  str_kml_line_pos_time        = strstr(str_kml_line, "TIMESTAMP" ) - str_kml_line;
  str_kml_line_pos_timed       = strstr(str_kml_line, "TIMEDESCR" ) - str_kml_line;
  str_kml_line_pos_color       = strstr(str_kml_line, "COLOR"     ) - str_kml_line;
  str_kml_line_len             = strlen(str_kml_line);

  str_kml_arrow_pos_lonlat     = strstr(str_kml_arrow, "LONLAT"    ) - str_kml_arrow;
  str_kml_arrow_pos_heading    = strstr(str_kml_arrow, "HEAD"      ) - str_kml_arrow;
  str_kml_arrow_pos_name       = strstr(str_kml_arrow, "NAME"      ) - str_kml_arrow;
  str_kml_arrow_pos_left       = strstr(str_kml_arrow, "LEFT"      ) - str_kml_arrow;
  str_kml_arrow_pos_left_stdev = strstr(str_kml_arrow, "LSTDV"     ) - str_kml_arrow;
  str_kml_arrow_pos_right      = strstr(str_kml_arrow, "RIGHT"     ) - str_kml_arrow;
  str_kml_arrow_pos_right_stdev= strstr(str_kml_arrow, "RSTDV"     ) - str_kml_arrow;
  str_kml_arrow_pos_n          = strstr(str_kml_arrow, "NM"        ) - str_kml_arrow;
  str_kml_arrow_pos_speed_min  = strstr(str_kml_arrow, "SPL"       ) - str_kml_arrow;
  str_kml_arrow_pos_speed_max  = strstr(str_kml_arrow, "SPH"       ) - str_kml_arrow;
  str_kml_arrow_pos_time       = strstr(str_kml_arrow, "TIMESTAMP" ) - str_kml_arrow;
  str_kml_arrow_pos_color      = strstr(str_kml_arrow, "COLOR"     ) - str_kml_arrow;
  str_kml_arrow_len            = strlen(str_kml_arrow);

  str_kml_footer_pos_longitude = strstr(str_kml_footer, "LONGITUDE") - str_kml_footer;
  str_kml_footer_pos_latitude  = strstr(str_kml_footer, "LATITUDE" ) - str_kml_footer;
  str_kml_footer_pos_heading   = strstr(str_kml_footer, "HEAD"     ) - str_kml_footer;
  str_kml_footer_pos_begin     = strstr(str_kml_footer, "TIMEBEGIN") - str_kml_footer;
  str_kml_footer_pos_end       = strstr(str_kml_footer, "TIMEEND"  ) - str_kml_footer;
  str_kml_footer_len           = strlen(str_kml_footer);

  str_kml_footer_simple_len    = strlen(str_kml_footer_simple);
}
// init buffer for subsequent adding lines and arrows
// first entry is arrow (not always used)
// subsequent entries are lines until end of buffer
void kml_buf_init(void)
{
  strcpy(kmlbuf, str_kml_arrow);
  
  kmlbuf_len = str_kml_arrow_len; // bytes in the buffer
  char *a = kmlbuf+str_kml_arrow_len; // pointer to the boffer

  for(; kmlbuf_len < sizeof(kmlbuf)-str_kml_line_len-1; a += str_kml_line_len, kmlbuf_len += str_kml_line_len)
    strcpy(a, str_kml_line);
  
  kmlbuf_pos = str_kml_arrow_len; // write position past arrow, default to first line
  kmlbuf_start = str_kml_arrow_len; // same as above is file write default starting point
}

void kml_header(char *name)
{
  sprintf(kmlbuf, str_kml_header,
    name,
    red_iri, 2.0/2.5*red_iri, 1.5/2.5*red_iri, 1.0/2.5*red_iri,
    0.5/2.5*red_iri, 0.3/2.5*red_iri);
}

// color 0-1023
uint32_t color32(uint16_t color)
{
/*
HSV to RGB conversion formula
When 0 ≤ H < 360, 0 ≤ S ≤ 1 and 0 ≤ V ≤ 1:
C = V × S
X = C × (1 - |(H / 60°) mod 2 - 1|)
m = V - C
(R',G',B') = (C,X,0)   0<=H<60
(R',G',B') = (X,C,0)  60<=H<120
(R',G',B') = (0,C,X) 120<=H<180
(R',G',B') = (0,X,C) 180<=H<240
(R',G',B') = (X,0,C) 240<=H<300
(R',G',B') = (C,0,X) 300<=H<360
(R,G,B) = ((R'+m)×255, (G'+m)×255, (B'+m)×255)
H=(1.0001-color)*0.8332
S=1
V=1
-----
C=1
X=1 - |(H / 60°) mod 2 - 1|
m=0
(R,G,B) = ((R'+m)×255, (G'+m)×255, (B'+m)×255)
*/
  if(color <    0) color = 0;
  if(color > 1023) color = 1023;
  uint16_t H = ((1023 - color)*1280)>>10; // 1280=0.8332*6*256 -> 0<H<6*256
  uint16_t X1 =   256 - abs(H % 512 - 256);
  uint8_t  X = X1 > 255 ? 255 : X1;
  uint32_t c32; // 0xF0BBGGRR
  //                         R      G          B
  if     (H<1*256)   c32 = 255 | (  X<<8)            ;
  else if(H<2*256)   c32 =   X | (255<<8)            ;
  else if(H<3*256)   c32 =       (255<<8) | (  X<<16);
  else if(H<4*256)   c32 =       (  X<<8) | (255<<16);
  else if(H<5*256)   c32 =   X            | (255<<16);
  else /* H<6*256 */ c32 = 255            | (  X<<16);
  return c32 | 0xF0000000;
}

void kml_line(struct s_kml_line *kl)
{
  if(kmlbuf_pos+str_kml_line_len > kmlbuf_len) // rather loose data than crash
    return;
  char *a = kmlbuf+kmlbuf_pos;

  sprintf(a+str_kml_line_pos_lonlat, "%+011.6f,%+010.6f %+011.6f,%+010.6f",
    kl->lon[0], kl->lat[0], kl->lon[1], kl->lat[1]);
  kmlbuf[kmlbuf_pos+str_kml_line_pos_lonlat+45] = '<'; // replace null

  sprintf(a+str_kml_line_pos_color, "%08X", color32(1024*kl->value/red_iri));
  kmlbuf[kmlbuf_pos+str_kml_line_pos_color+8] = '<'; // replace null

  sprintf(a+str_kml_line_pos_name, "%5.2f", kl->value < 99.99 ? kl->value : 99.99);
  kmlbuf[kmlbuf_pos+str_kml_line_pos_name+5] = '<'; // replace null

  sprintf(a+str_kml_line_pos_left20, "%5.2f", kl->left20 < 99.99 ? kl->left20 : 99.99);
  kmlbuf[kmlbuf_pos+str_kml_line_pos_left20+5] = ' '; // replace null

  sprintf(a+str_kml_line_pos_right20, "%5.2f", kl->right20 < 99.99 ? kl->right20 : 99.99);
  kmlbuf[kmlbuf_pos+str_kml_line_pos_right20+5] = ' '; // replace null

  sprintf(a+str_kml_line_pos_left100, "%5.2f", kl->left100 < 99.99 ? kl->left100 : 99.99);
  kmlbuf[kmlbuf_pos+str_kml_line_pos_left100+5] = ' '; // replace null

  sprintf(a+str_kml_line_pos_right100, "%5.2f", kl->right100 < 99.99 ? kl->right100 : 99.99);
  kmlbuf[kmlbuf_pos+str_kml_line_pos_right100+5] = ' '; // replace null

  sprintf(a+str_kml_line_pos_speed, "%5.1f", kl->speed_kmh);
  kmlbuf[kmlbuf_pos+str_kml_line_pos_speed+5] = ' '; // replace null

  memcpy(a+str_kml_line_pos_time, kl->timestamp, 22);

  kmlbuf_pos += str_kml_line_len;
}

// overwrite arrow data. Arrow is the first entry in kmlbuf.
// kmlbuf holds 1 arrow and approx 12 lines
// arrow can't be written more than 1 every 12 lines
void kml_arrow(struct s_kml_arrow *ka)
{
  sprintf(kmlbuf+str_kml_arrow_pos_lonlat, "%+011.6f,%+010.6f",
    ka->lon, ka->lat);
  kmlbuf[str_kml_arrow_pos_lonlat+22] = '<'; // replace null

  sprintf(kmlbuf+str_kml_arrow_pos_heading, "%05.1f", (float)(((int)(10*ka->heading)+1800)%3600)/10.0);
  kmlbuf[str_kml_arrow_pos_heading+5] = '<'; // replace null

  sprintf(kmlbuf+str_kml_arrow_pos_color, "%08X", color32(1024*ka->value/red_iri));
  kmlbuf[str_kml_arrow_pos_color+8] = '<'; // replace null

  sprintf(kmlbuf+str_kml_arrow_pos_name, "%5.2f", ka->value < 99.99 ? ka->value : 99.99);
  kmlbuf[str_kml_arrow_pos_name+5] = '<'; // replace null

  sprintf(kmlbuf+str_kml_arrow_pos_left, "%5.2f", ka->left < 99.99 ? ka->left : 99.99);
  kmlbuf[str_kml_arrow_pos_left+5] = ' '; // replace null

  sprintf(kmlbuf+str_kml_arrow_pos_left_stdev, "%5.2f", ka->left_stdev < 99.99 ? ka->left_stdev : 99.99);
  kmlbuf[str_kml_arrow_pos_left_stdev+5] = ' '; // replace null

  sprintf(kmlbuf+str_kml_arrow_pos_right, "%5.2f", ka->right < 99.99 ? ka->right : 99.99);
  kmlbuf[str_kml_arrow_pos_right+5] = ' '; // replace null

  sprintf(kmlbuf+str_kml_arrow_pos_right_stdev, "%5.2f", ka->right_stdev < 99.99 ? ka->right_stdev : 99.99);
  kmlbuf[str_kml_arrow_pos_right_stdev+5] = ' '; // replace null

  sprintf(kmlbuf+str_kml_arrow_pos_n, "%2d", ka->n < 99 ? ka->n : 99);
  kmlbuf[str_kml_arrow_pos_n+2] = ' '; // replace null

  sprintf(kmlbuf+str_kml_arrow_pos_speed_min, "%3d", ka->speed_min_kmh);
  kmlbuf[str_kml_arrow_pos_speed_min+3] = '-'; // replace null
  sprintf(kmlbuf+str_kml_arrow_pos_speed_max, "%3d", ka->speed_max_kmh);
  kmlbuf[str_kml_arrow_pos_speed_max+3] = ' '; // replace null

  memcpy(kmlbuf+str_kml_arrow_pos_time, ka->timestamp, 22);

  kmlbuf_start = 0; // include arrow in the output
}

void kml_footer(char *begin, char *end)
{
  strcpy(kmlbuf, str_kml_footer);

  sprintf(kmlbuf+str_kml_footer_pos_longitude, "%+011.6f", 16.0);
  kmlbuf[str_kml_footer_pos_longitude+11] = '<'; // replace null

  sprintf(kmlbuf+str_kml_footer_pos_latitude, "%+010.6f", 46.0);
  kmlbuf[str_kml_footer_pos_latitude+10] = '<'; // replace null

  sprintf(kmlbuf+str_kml_footer_pos_heading, "%05.1f", 0.0);
  kmlbuf[str_kml_footer_pos_heading+5] = '<'; // replace null

  memcpy(kmlbuf+str_kml_footer_pos_begin, begin, 22);
  memcpy(kmlbuf+str_kml_footer_pos_end, end, 22);
}
