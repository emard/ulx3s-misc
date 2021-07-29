#ifndef KML_H
#define KML_H

struct s_kml_arrow
{
  float lon, lat, value, heading;
  char *timestamp, *description;
};

struct s_kml_line
{
  float lon1, lat1, lon2, lat2, value;
  char *timestamp, *description;
};

extern char kmlbuf[];
extern int kmlbuf_pos;
extern int kmlbuf_len;

extern const char *str_kml_header;
extern int str_kml_header_len;
extern int str_kml_footer_len;

void kml_init(void);
void kml_header(void);
void kml_footer(char *begin, char *end);
#endif
