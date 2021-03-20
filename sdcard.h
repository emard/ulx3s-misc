#include "FS.h"
#include "SD_MMC.h"
#define SPI_READER_BUF_SIZE 6144
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