#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdint.h>

FILE *fkml;
char kmline[16384];

struct s_kml_arrow
{
  float lon1, lat1, value, heading;
  uint32_t color;
  char *timestamp, *description;
};
struct s_kml_arrow x_kml_arrow[1];

struct s_kml_line
{
  float lon1, lat1, lon2, lat2, left, right;
  uint32_t color;
  char *timestamp, *description;
};
struct s_kml_line x_kml_line[1];

void kml_open(void)
{
  fkml = fopen("/tmp/demo.kml", "wb");
}

void kml_header(void)
{
  char *header = "\
<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n\
  <Document id=\"docid\">\n\
    <name>doc name</name>\n\
    <description>description</description>\n\
    <LookAt>\n\
      <longitude>16.000000</longitude>\n\
      <latitude>46.000000</latitude>\n\
      <heading>0</heading>\n\
      <tilt>0</tilt>\n\
      <range>2000</range>\n\
      <altitudeMode>relativeToGround</altitudeMode>\n\
      <TimeSpan>\n\
        <begin>2021-07-24T11:54:18.0Z</begin>\n\
        <end>2021-07-24T11:56:11.0Z</end>\n\
      </TimeSpan>\n\
    </LookAt>\n\
    <visibility>1</visibility>\n\
    <Folder id=\"id2\">\n\
      <name>name2</name>\n\
      <description>description2</description>\n\
      <visibility>1</visibility>\n\
";
  fwrite(header, strlen(header), 1, fkml);
}

void kml_line(struct s_kml_line *kl)
{
  sprintf(kmline, "\
      <Placemark id=\"id\">\n\
        <name>0.15</name>\n\
        <description>%s</description>\n\
        <visibility>1</visibility>\n\
        <Style>\n\
          <LineStyle>\n\
            <color>F0FF00AF</color>\n\
            <width>6</width>\n\
          </LineStyle>\n\
        </Style>\n\
        <TimeStamp>\n\
          <when>2021-07-24T11:54:19+00:00</when>\n\
        </TimeStamp>\n\
        <LineString>\n\
          <coordinates>%.6f,%.6f %.6f,%.6f</coordinates>\n\
        </LineString>\n\
      </Placemark>\n\
",
      "descript", 
      kl->lat1, kl->lon1, kl->lat2, kl->lon2);
  fwrite(kmline, strlen(kmline), 1, fkml);
}

void kml_arrow(struct s_kml_arrow *ka)
{
  sprintf(kmline, "\
      <Placemark id=\"id\">\n\
        <name>0.15</name>\n\
        <description>%s</description>\n\
        <visibility>1</visibility>\n\
        <Style>\n\
          <IconStyle id=\"id\">\n\
            <color>F0FF00FE</color>\n\
            <scale>1.0</scale>\n\
            <heading>180.0</heading>\n\
            <Icon>\n\
              <href>http://maps.google.com/mapfiles/kml/shapes/arrow.png</href>\n\
            </Icon>\n\
          </IconStyle>\n\
        </Style>\n\
        <TimeStamp>\n\
          <when>2021-07-24T11:54:19+00:00</when>\n\
        </TimeStamp>\n\
        <Point>\n\
          <coordinates>%.6f,%.6f</coordinates>\n\
        </Point>\n\
      </Placemark>\n\
",
      "descript", 
      ka->lat1, ka->lon1);
  fwrite(kmline, strlen(kmline), 1, fkml);
}

void kml_content(void)
{
  x_kml_line->lat1 = 16.000000;
  x_kml_line->lon1 = 46.000000;
  x_kml_line->lat2 = 16.000000;
  x_kml_line->lon2 = 46.000500;
  kml_line(x_kml_line);

  x_kml_arrow->lat1 = 16.000000;
  x_kml_arrow->lon1 = 46.000000;
  kml_arrow(x_kml_arrow);
}

void kml_footer(void)
{
  char *footer = "\
    </Folder>\n\
  </Document>\n\
</kml>\n\
";
  fwrite(footer, strlen(footer), 1, fkml);
}

void kml_close(void)
{
  fclose(fkml);
}

int main(int argc, char *argv[])
{
  kml_open();
  kml_header();
  kml_content();
  kml_footer();
  kml_close();
}
