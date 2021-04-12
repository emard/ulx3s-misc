#include "FS.h"
#include "SD_MMC.h"
// hardware buffer size in bytes at fpga core (must be divisible by 12)
// 3072, 6144, 9216, 12288, 15360
#define SPI_READER_BUF_SIZE 9216
extern int card_is_mounted;
void mount(void);
void umount(void);
void spi_init(void);
void rds_init(void);
void spi_rds_write(void);
void rds_ct_tm(struct tm *tm);
void adxl355_init(void);
uint8_t adxl355_available(void);
void ls(void);
void open_logs(void);
void write_logs(void);
void write_tag(char *a);
void play_pcm(int n);
void open_pcm(char *wav); // open wav filename
void beep_pcm(int n);
void write_rds(uint8_t *a, int n);
void close_logs(void);
int are_logs_open(void);
void spi_slave_test(void);
void spi_direct_test(void);
