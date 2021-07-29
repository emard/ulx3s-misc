#ifndef KML_H
#define KML_H

struct s_kml_arrow
{
  float lon, lat, value, heading;
  char *timestamp, *description;
};
extern struct s_kml_arrow x_kml_arrow[];

struct s_kml_line
{
  float lon[2], lat[2], value;
  char *timestamp, *description;
};
extern struct s_kml_line x_kml_line[];

extern char kmlbuf[];
extern int kmlbuf_start;
extern int kmlbuf_pos;
extern int kmlbuf_len;

extern const char *str_kml_header;
extern int str_kml_header_len;
extern int str_kml_footer_len;
extern int str_kml_line_len;
extern int str_kml_arrow_len;

void kml_init(void);
void kml_buf_init(void);
void kml_header(void);
void kml_footer(char *begin, char *end);

void kml_arrow(struct s_kml_arrow *ka);
void kml_line(struct s_kml_line *kl);

void kml_demo_line(void); // generate some line for debugging

#endif
