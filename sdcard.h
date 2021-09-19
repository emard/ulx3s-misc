#ifndef SDCARD_H
#define SDCARD_H

#include "FS.h"
#include "SD_MMC.h"
#include "RDS.h"
#include "nmea.h"
// hardware buffer size in bytes at fpga core (must be divisible by 12)
// 3072, 6144, 9216, 12288, 15360
#define SPI_READER_BUF_SIZE 9216
extern int card_is_mounted;
extern int pcm_is_open;
extern int sensor_check_status;
extern int speed_ckt; // centi-knots speed, 100 ckt = 1 kt = 0.514444 m/s = 1.852 km/h
extern int speed_mms; // mm/s speed
extern int speed_kmh; // km/h speed
extern int fast_enough; // logging flag when fast enough
extern int mode_obd_gps;
extern float srvz_iri100, iri[2], iriavg, srvz2_iri20, iri20[2], iri20avg;
extern char iri2digit[4];
extern char lastnmea[256];
extern struct int_latlon last_latlon;
extern RDS rds;
// config file parsing
extern uint8_t GPS_MAC[6], OBD_MAC[6];
#define AP_MAX 16 /* max number of APs */
extern String  GPS_NAME, GPS_PIN, OBD_NAME, OBD_PIN, AP_PASS[], DNS_HOST;
extern uint8_t datetime_is_set;
extern struct tm tm, tm_session; // tm_session gives new filename when reconnected
extern uint64_t free_bytes;
extern uint8_t log_wav_kml; // 1-wav 2-kml 3-both
extern uint8_t KMH_START, KMH_STOP;
extern uint8_t KMH_BTN;
extern uint8_t G_RANGE; // +-2/4/8 g sensor range for reading +-32000
extern uint32_t REPORT_mm, REPORT2_mm; // mm report each travel distance
extern uint8_t adxl355_regio;
extern uint8_t adxl_devid_detected;

void mount(void);
void umount(void);
void spi_init(void);
void rds_init(void);
void spi_speed_write(int spd);
void spi_srvz_read(uint32_t *srvz);
uint8_t spi_btn_read(void);
void spi_rds_write(void);
void rds_message(struct tm *tm);
void rds_report_ip(struct tm *tm);
void adxl355_init(void);
uint8_t adxl355_available(void);
void ls(void);
void SD_status();
void open_logs(struct tm *tm);
void write_logs(void);
void write_stop_delimiter(void);
void flush_logs(void);
void write_last_nmea(void);
void read_last_nmea(void);
void set_date_from_tm(struct tm *tm);
void write_tag(char *a);
void write_log_kml(uint8_t force);
int play_pcm(int n);
int open_pcm(char *wav); // open wav filename
void beep_pcm(int n);
void write_rds(uint8_t *a, int n);
void finalize_data(struct tm *tm);
void close_logs(void);
void spi_slave_test(void);
void spi_direct_test(void);
void read_cfg(void);

#endif
