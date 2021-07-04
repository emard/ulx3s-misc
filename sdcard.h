#include "FS.h"
#include "SD_MMC.h"
#include "RDS.h"
// hardware buffer size in bytes at fpga core (must be divisible by 12)
// 3072, 6144, 9216, 12288, 15360
#define SPI_READER_BUF_SIZE 9216
extern int card_is_mounted;
extern int pcm_is_open;
extern int sensor_check_status;
extern int knots; // speed knots, 1 knot = 0.514444 m/s = 1.852 km/h
extern int fast_enough; // logging flag when fast enough
extern float iri[2],iriavg;
extern char iri2digit[4];
extern RDS rds;
void mount(void);
void umount(void);
void spi_init(void);
void rds_init(void);
void spi_speed_write(float spd);
void spi_srvz_read(int32_t *srvz);
void spi_rds_write(void);
void rds_message(struct tm *tm);
void adxl355_init(void);
uint8_t adxl355_available(void);
void ls(void);
void open_logs(struct tm *tm);
void write_logs(void);
void write_tag(char *a);
int play_pcm(int n);
int open_pcm(char *wav); // open wav filename
void beep_pcm(int n);
void write_rds(uint8_t *a, int n);
void close_logs(void);
int are_logs_open(void);
void spi_slave_test(void);
void spi_direct_test(void);
