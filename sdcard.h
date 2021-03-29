#include "FS.h"
#include "SD_MMC.h"
#define SPI_READER_BUF_SIZE 6144
// write to SD when more than BUF_DATA_WRITE bytes are collected
#define BUF_DATA_WRITE 3000
void mount(void);
void spi_init(void);
void adxl355_init(void);
uint8_t adxl355_available(void);
void ls(void);
void open_logs(void);
void write_logs(void);
void close_logs(void);
void spi_slave_test(void);
void spi_direct_test(void);
