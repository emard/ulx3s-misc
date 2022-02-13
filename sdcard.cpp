#include "pins.h"
#include "sdcard.h"
#include "adxl355.h"
#include "adxrs290.h"
#include "nmea.h"
#include "kml.h"
#include "geostat.h"
#include <sys/time.h>
#include <WiFi.h> // for rds_report_ip()

// TODO
// too much of various code is put into this module
// big cleanup needed, code from here should be distributed
// to multiple modules for readability
// (sdcard, adxl master, adxl reader, audio player, ascii tagger)

RDS rds;

// Manage Libraries -> ESP32DMASPI
// Version 0.1.0 tested
// Version 0.1.1 and 0.1.2 compile with arduino 1.8.19
// Version 0.2.0 doesn't compile
#include <ESP32DMASPIMaster.h> // Version 0.1.0 tested
ESP32DMASPI::Master master;
uint8_t* spi_master_tx_buf;
uint8_t* spi_master_rx_buf;
static const uint32_t BUFFER_SIZE = (SPI_READER_BUF_SIZE+6+4) & 0xFFFFFFFC; // multiply of 4
uint8_t  last_sensor_reading[12];

// config file parsing
uint8_t GPS_MAC[6], OBD_MAC[6];
String  GPS_NAME, GPS_PIN, OBD_NAME, OBD_PIN, AP_PASS[AP_MAX], DNS_HOST;

File file_kml, file_accel, file_pcm, file_cfg;
char filename_data[256];
char *filename_lastnmea = (char *)"/profilog/var/lastnmea.txt";
char *filename_fmfreq   = (char *)"/profilog/var/fmfreq.txt";
char lastnmea[256]; // here is read content from filename_lastnmea
char *linenmea; // pointer to current nmea line
int card_is_mounted = 0;
int logs_are_open = 0;
int pcm_is_open = 0;
int sensor_check_status = 0;
int speed_ckt = -1; // centi-knots speed (kt*100)
int speed_mms = -1; // mm/s speed
int speed_kmh = -1; // km/h speed
int fast_enough = 0; // for speed logging hysteresis
uint8_t KMH_START = 12, KMH_STOP = 6; // km/h start/stop speed hystereis
uint8_t KMH_BTN = 0; // debug btn2 for fake km/h
int mode_obd_gps = 0; // alternates 0:OBD and 1:GPS
uint8_t gps_obd_configured = 0; // existence of (1<<0):OBD config, (1<<1):GPS config
float srvz_iri100, iri[2], iriavg, srvz2_iri20, iri20[2], iri20avg;
float temp[2]; // sensor temperature
char iri2digit[4] = "0.0";
char iri99avg2digit[4] = "0.0";
uint32_t iri99sum = 0, iri99count = 0, iri99avg = 0; // collect session average
struct int_latlon last_latlon; // degrees and microminutes
struct tm tm, tm_session; // tm_session gives new filename_data when reconnected
uint8_t log_wav_kml = 3; // 1-wav 2-kml 3-both
uint8_t G_RANGE = 8; // +-2/4/8 g sensor range (at digital reading +-32000)
uint8_t FILTER_ADXL355_CONF = 0; // see datasheet adxl355 p.38 0:1kHz ... 10:0.977Hz
uint8_t FILTER_ADXRS290_CONF = 0; // see datasheet adxrs290 p.11 0:480Hz ... 7:20Hz
float   T_OFFSET_ADXL355_CONF[2]  = {0.0, 0.0}; // L,R
float   T_SLOPE_ADXL355_CONF[2]   = {1.0, 1.0}; // L,R
float   T_OFFSET_ADXRS290_CONF[2] = {0.0, 0.0}; // L,R
float   T_SLOPE_ADXRS290_CONF[2]  = {1.0, 1.0}; // L,R
uint8_t  KMH_REPORT1 = 30; // when speed_kmh >= KMH_REPORT1 use MM_REPORT1, else MM_REPORT2
uint32_t MM_REPORT1  = 100000, MM_REPORT2 = 20000; // mm report every travel distance 100 m, 20 m
uint8_t adxl355_regio = 1; // REG I/O protocol 1:ADXL355 0:ADXRS290
uint8_t adxl_devid_detected = 0; // 0xED for ADXL355, 0x92 for ADXRS290
uint32_t fm_freq[2] = {107900000, 87600000};
uint8_t fm_freq_cursor = 0; // cursor highlighting fm freq bitmask 0,1,2
uint8_t btn, btn_prev;

// SD status
uint64_t total_bytes = 0, used_bytes, free_bytes;
uint32_t free_MB;

void adxl355_write_reg(uint8_t a, uint8_t v)
{
  if(adxl355_regio)
    spi_master_tx_buf[0] = a*2; // adxl355 write reg addr a
  else
    spi_master_tx_buf[0] = a; // adxrs290 write reg addr a
  spi_master_tx_buf[1] = v;
  //digitalWrite(PIN_CSN, 0);
  master.transfer(spi_master_tx_buf, 2);
  //digitalWrite(PIN_CSN, 1);
}

uint8_t adxl355_read_reg(uint8_t a)
{
  if(adxl355_regio)
    spi_master_tx_buf[0] = a*2+1; // adxl355 read reg addr a
  else
    spi_master_tx_buf[0] = a|0x80; // adxrs290 read reg addr a
  //digitalWrite(PIN_CSN, 0);
  master.transfer(spi_master_tx_buf, spi_master_rx_buf, 2);
  //digitalWrite(PIN_CSN, 1);
  return spi_master_rx_buf[1];
}

// write ctrl byte to spi ram slave addr 0xFF000000
void adxl355_ctrl(uint8_t x)
{
  spi_master_tx_buf[0] = 0;    // cmd write to spi ram slave
  spi_master_tx_buf[1] = 0xFF; // address 0xFF ...
  spi_master_tx_buf[2] = 0x00; // adresss
  spi_master_tx_buf[3] = 0x00; // adresss
  spi_master_tx_buf[4] = 0x00; // adresss
  spi_master_tx_buf[5] = x;
  master.transfer(spi_master_tx_buf, 6);
}

//                   sensor type         sclk polarity         sclk phase
#define CTRL_SELECT (adxl355_regio<<2)|((!adxl355_regio)<<3)|((!adxl355_regio)<<4)

// turn sensor power on, set range, filtering, sync mode
void init_sensors(void)
{
  if(adxl_devid_detected == 0xED) // ADXL355
  {
    adxl355_write_reg(ADXL355_POWER_CTL, 0); // 0: turn device ON
    // i=1-3 range 1:+-2g, 2:+-4g, 3:+-8g
    // high speed i2c, INT1,INT2 active high
    adxl355_write_reg(ADXL355_RANGE, G_RANGE == 2 ? 1 : G_RANGE == 4 ? 2 : /* G_RANGE == 8 ? */ 3 );
    // LPF FILTER i=0-10, 1kHz/2^i, 0:1kHz ... 10:0.977Hz
    adxl355_write_reg(ADXL355_FILTER, FILTER_ADXL355_CONF);
    // sync: 0:internal, 2:external sync with interpolation, 5:external clk/sync < 1066 Hz no interpolation, 6:external clk/sync with interpolation
    adxl355_write_reg(ADXL355_SYNC, 0xC0 | 2); // 0: internal, 2: takes external sync to drdy pin, 0xC0 undocumented, seems to prevent glitches
  }
  if(adxl_devid_detected == 0x92) // ADXRS290 Gyro
  {
    adxl355_write_reg(ADXRS290_POWER_CTL, ADXRS290_POWER_GYRO | ADXRS290_POWER_TEMP); // turn device ON
    // [7:4] HPF 0.011-11.30 Hz, [2:0] LPF 480-20 Hz, see datasheet
    adxl355_write_reg(ADXRS290_FILTER, FILTER_ADXRS290_CONF);
  }
}

// from core indirect (automatic sensor reading)
// temporary switch to core direct (SPI to sensors)
// read temperatures
// switch back to core indirect (automatic sensor reading)
void read_temperature(void)
{
  if(adxl_devid_detected == 0xED) // ADXL355
  {
    for(uint8_t lr = 0; lr < 2; lr++)
    {
      adxl355_ctrl(lr|2|CTRL_SELECT); // 2 core direct mode, 4 SCLK inversion
      // repeatedly read raw temperature registers until 2 same readings
      uint16_t T[2] = {0xFFFF,0xFFFE}; // any 2 different numbers that won't accidentally appear at reading
      for(int i = 0; i < 1000 && T[0] != T[1]; i++)
        T[i&1] = ((adxl355_read_reg(ADXL355_TEMP2) & 0xF)<<8) | adxl355_read_reg(ADXL355_TEMP1);
      temp[lr] = T_OFFSET_ADXL355_CONF[lr] + 25.0 + (T[0]-ADXL355_TEMP_AT_25C)*ADXL355_TEMP_SCALE*T_SLOPE_ADXL355_CONF[lr]; // convert to deg C
    }
  }
  if(adxl_devid_detected == 0x92) // ADXRS290 Gyro
  {
    for(uint8_t lr = 0; lr < 2; lr++)
    {
      adxl355_ctrl(lr|2|CTRL_SELECT); // 2 core direct mode, 4 SCLK inversion
      // repeatedly read raw temperature registers until 2 same readings
      uint16_t T[2] = {0xFFFF,0xFFFE}; // any 2 different numbers that won't accidentally appear at reading
      for(int i = 0; i < 1000 && T[0] != T[1]; i++)
        T[i&1] = ((adxl355_read_reg(ADXRS290_TEMP_H) & 0xF)<<8) | adxl355_read_reg(ADXRS290_TEMP_L);
      temp[lr] = T_OFFSET_ADXRS290_CONF[lr] + T[0]*ADXRS290_TEMP_SCALE*T_SLOPE_ADXRS290_CONF[lr]; // convert to deg C
    }
  }
}

void warm_init_sensors(void)
{
  adxl355_ctrl(2|CTRL_SELECT);
  delay(2); // wait for request direct mode to be accepted
  init_sensors();
  read_temperature();
  adxl355_ctrl(CTRL_SELECT); // 2:request core indirect mode
  delay(2); // wait for direct mode to finish
}

void debug_sensors_print(void)
{
  char sprintf_buf[80];
  if(adxl_devid_detected == 0xED) // ADXL355
  {
    // print to check is Accel working
    for(int i = 0; i < 1000; i++)
    {
      sprintf(sprintf_buf, "ID=%02X%02X X=%02X%02X Y=%02X%02X Z=%02X%02X",
        adxl355_read_reg(0),
        adxl355_read_reg(1),
        adxl355_read_reg(ADXL355_XDATA3),
        adxl355_read_reg(ADXL355_XDATA2),
        adxl355_read_reg(ADXL355_YDATA3),
        adxl355_read_reg(ADXL355_YDATA2),
        adxl355_read_reg(ADXL355_ZDATA3),
        adxl355_read_reg(ADXL355_ZDATA2)
      );
      Serial.println(sprintf_buf);
    }
  }
  if(adxl_devid_detected == 0x92) // ADXRS290 Gyro
  {
    // print to check is Gyro working
    for(int i = 0; i < 1000; i++)
    {
      sprintf(sprintf_buf, "X=%02X%02X Y=%02X%02X",
        adxl355_read_reg(ADXRS290_GYRO_XH),
        adxl355_read_reg(ADXRS290_GYRO_XL),
        adxl355_read_reg(ADXRS290_GYRO_YH),
        adxl355_read_reg(ADXRS290_GYRO_YL)
      );
      Serial.println(sprintf_buf);
    }
  }
}

void cold_init_sensors(void)
{
  uint8_t chipid[4];
  uint32_t serialno[2];
  char sprintf_buf[80];

  // autodetect regio protocol.
  // try 2 different regio protocols
  // until read reg(1) = 0x1D (common for both sensor types)
  // 2<<0 direct mode L/R switch when reading data from sensor
  // 2<<1 direct mode request
  // 2<<2 sensor type
  // 2<<3 clock polarity
  // 2<<4 clock phase
  adxl355_ctrl(2|CTRL_SELECT);
  delay(2); // wait for request direct mode to be accepted
  if(adxl_devid_detected == 0)
  {
    master.setFrequency(4000000); // 5 MHz max ADXRS290
    for(int8_t j = 1; j >= 0; j--)
    {
      // first try 1:ADXL355, then 0:ADXRS290
      // otherwise ADXL355 will be spoiled
      adxl355_regio = j;
      for(int8_t lr = 0; lr < 2; lr++)
      {
        adxl355_ctrl(lr|2|CTRL_SELECT); // 2 core direct mode, 4 SCLK inversion
        if(adxl355_read_reg(1) == 0x1D)
          goto read_chip_id; // ends for-loop
      }
    }
  }
  read_chip_id:;
  // now read full 4 bytes of chip id
  for(uint8_t i = 0; i < 4; i++)
    chipid[i] = adxl355_read_reg(i);
  if(chipid[0] == 0xAD && chipid[1] == 0x1D) // ADXL device
    adxl_devid_detected = chipid[2];
  serialno[0] = 0;
  serialno[1] = 0;
  if(adxl_devid_detected == 0xED) // ADXL355
    master.setFrequency(4000000); // 8 MHz max ADXL355, no serial number
  if(adxl_devid_detected == 0x92) // ADXRS290 gyroscope has serial number
  { // read serial number
    master.setFrequency(4000000); // 5 MHz max ADXRS290, read serial number
    for(uint8_t lr = 0; lr < 2; lr++)
    {
      adxl355_ctrl(lr|2|CTRL_SELECT); // 2 core direct mode, 4 SCLK inversion
      for(uint8_t i = 0; i < 4; i++)
        serialno[lr] = (serialno[lr] << 8) | adxl355_read_reg(i|4);
    }
  }
  sprintf(sprintf_buf, "ADX CHIP ID: %02X %02X %02X %02X S/N L: %08X R: %08X",
      chipid[0], chipid[1], chipid[2], chipid[3], serialno[0], serialno[1]
  );
  Serial.println(sprintf_buf);
  init_sensors();
  //debug_sensors_print();
  read_temperature();
  sprintf(sprintf_buf, "TL=%4.1f'C TR=%4.1f'C", temp[0], temp[1]);
  Serial.println(sprintf_buf);
  adxl355_ctrl(CTRL_SELECT); // 2:request core indirect mode
  delay(2); // wait for direct mode to finish
}


uint8_t adxl355_available(void)
{
  // read number of entries in the fifo
  spi_master_tx_buf[0] = ADXL355_FIFO_ENTRIES*2+1; // FIFO_ENTRIES read request
  //digitalWrite(PIN_CSN, 0);
  master.transfer(spi_master_tx_buf, spi_master_rx_buf, 2);
  //digitalWrite(PIN_CSN, 1);
  return spi_master_rx_buf[1]/3;
}

// read current write pointer of the spi slave
uint16_t spi_slave_ptr(void)
{
  spi_master_tx_buf[0] = 1; // 1: read ram
  spi_master_tx_buf[1] = 1; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  spi_master_tx_buf[5] = 0; // dummy
  master.transfer(spi_master_tx_buf, spi_master_rx_buf, 8); // read, last 2 bytes are ptr value
  return spi_master_rx_buf[6]+(spi_master_rx_buf[7]<<8);
}

// read n bytes from SPI address a and write to dst
// result will appear at spi_master_rx_buf at offset 6
void spi_slave_read(uint16_t a, uint16_t n)
{
  spi_master_tx_buf[0] = 1; // 1: read ram
  spi_master_tx_buf[1] = 0; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = a >> 8; // addr [15: 8]
  spi_master_tx_buf[4] = a; // addr [ 7: 0] lsb
  spi_master_tx_buf[5] = 0; // dummy
  master.transfer(spi_master_tx_buf, spi_master_rx_buf, 6+n); // read, last 2 bytes are ptr value
}

// read fifo to 16-buffer
uint8_t adxl355_rdfifo16(void)
{
  uint8_t n = adxl355_available();
  //n = 1; // debug
  for(uint8_t i = 0; i != n; i++)
  {
    spi_master_tx_buf[0] = ADXL355_FIFO_DATA*2+1; // FIFO_DATA read request
    //spi_master_tx_buf[0] = ADXL355_XDATA3*2+1; // current data
    //digitalWrite(PIN_CSN, 0);
    master.transfer(spi_master_tx_buf, spi_master_rx_buf, 10);
    //digitalWrite(PIN_CSN, 1);
    //spi_master_rx_buf[1] = 10; // debug
    //spi_master_rx_buf[2] = 12; // debug
    for(uint8_t j = 0; j != 3; j++)
    {
      uint16_t a = 1+i*6+j*2;
      uint16_t b = 1+j*3;
      for(uint8_t k = 0; k != 2; k++)
        spi_master_tx_buf[a-k] = spi_master_rx_buf[b+k];
        //spi_master_tx_buf[a-k] = i; // debug
    }
  }
  return n; // result is in spi_master_tx_buf
}

void spi_init(void)
{
    // to use DMA buffer, use these methods to allocate buffer
    spi_master_tx_buf = master.allocDMABuffer(BUFFER_SIZE);
    spi_master_rx_buf = master.allocDMABuffer(BUFFER_SIZE);

    // adxl355   needs SPI_MODE1 (all lines directly connected)
    // spi_slave needs SPI_MODE3
    // adxl355  direct can use SPI_MODE3 with sclk inverted
    // adxrs290 direct can use SPI_MODE3 with sclk normal
    master.setDataMode(SPI_MODE3); // for DMA, only 1 or 3 is available
    master.setFrequency(4000000); // Hz 5 MHz initial, after autodect ADXL355: 8 MHz, ADXRS290: 5 MHz
    master.setMaxTransferSize(BUFFER_SIZE); // bytes
    master.setDMAChannel(1); // 1 or 2 only
    master.setQueueSize(1); // transaction queue size
    pinMode(PIN_CSN, OUTPUT);
    digitalWrite(PIN_CSN, 1);
    // VSPI = CS:  5, CLK: 18, MOSI: 23, MISO: 19
    // HSPI = CS: 15, CLK: 14, MOSI: 13, MISO: 12
    master.begin(VSPI, PIN_SCK, PIN_MISO, PIN_MOSI, PIN_CSN); // use -1 if no CSN
}

// must be called after spi_init when buffer is allocated
void rds_init(void)
{
  rds.setmemptr(spi_master_tx_buf+5);
}

// speed in mm/s
void spi_speed_write(int spd)
{
  uint32_t icvx  = spd > 0 ? (adxl355_regio ? 40181760/spd : 5719) : 0; // spd is in mm/s
  uint16_t vx    = spd > 0 ? spd : 0;
  spi_master_tx_buf[0] = 0; // 0: write ram
  spi_master_tx_buf[1] = 0x2; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  spi_master_tx_buf[5] = vx>>8;
  spi_master_tx_buf[6] = vx;
  spi_master_tx_buf[7] = icvx>>24;
  spi_master_tx_buf[8] = icvx>>16;
  spi_master_tx_buf[9] = icvx>>8;
  spi_master_tx_buf[10]= icvx;
  master.transfer(spi_master_tx_buf, 5+4+2); // write speed binary
}

// returns 
// [um/m] sum abs(vz) over 100m/0.05m = 2000 points integer sum
// [um/m] sum abs(vz) over  20m/0.05m =  400 points integer sum
void spi_srvz_read(uint32_t *srvz)
{
  spi_master_tx_buf[0] = 1; // 1: read ram
  spi_master_tx_buf[1] = 0x2; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  spi_master_tx_buf[5] = 0; // dummy
  master.transfer(spi_master_tx_buf, spi_master_rx_buf, 6+4*4); // read srvz binary
  srvz[0] = (spi_master_rx_buf[ 6]<<24)|(spi_master_rx_buf[ 7]<<16)|(spi_master_rx_buf[ 8]<<8)|(spi_master_rx_buf[ 9]);
  srvz[1] = (spi_master_rx_buf[10]<<24)|(spi_master_rx_buf[11]<<16)|(spi_master_rx_buf[12]<<8)|(spi_master_rx_buf[13]);
  srvz[2] = (spi_master_rx_buf[14]<<24)|(spi_master_rx_buf[15]<<16)|(spi_master_rx_buf[16]<<8)|(spi_master_rx_buf[17]);
  srvz[3] = (spi_master_rx_buf[18]<<24)|(spi_master_rx_buf[19]<<16)|(spi_master_rx_buf[20]<<8)|(spi_master_rx_buf[21]);
}

uint8_t spi_btn_read(void)
{
  spi_master_tx_buf[0] = 1; // 1: read ram
  spi_master_tx_buf[1] = 0xB; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  spi_master_tx_buf[5] = 0; // dummy
  master.transfer(spi_master_tx_buf, spi_master_rx_buf, 6+1); // read srvz binary
  return spi_master_rx_buf[6];
}

void spi_rds_write(void)
{
  spi_master_tx_buf[0] = 0; // 0: write ram
  spi_master_tx_buf[1] = 0xD; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  rds.ta(0);
  rds.ps((char *)"RESTART ");
  //               1         2         3         4         5         6
  //      1234567890123456789012345678901234567890123456789012345678901234
  rds.rt((char *)"Restart breaks normal functioning. Firmware needs maintenance.  ");
  rds.ct(2000,0,1,0,0,0);
  master.transfer(spi_master_tx_buf, 5+(4+16+1)*13); // write RDS binary
  if(0)
  {
    for(int i = 0; i < 5+(4+16+1)*13; i++)
    {
      Serial.print(spi_master_tx_buf[i], HEX);
      Serial.print(" ");
    }
    Serial.println("RDS set");
  }
}

void SD_status(void)
{
  if(card_is_mounted)
  {
    total_bytes = SD_MMC.totalBytes();
    used_bytes = SD_MMC.usedBytes();
    free_bytes = total_bytes-used_bytes;
    free_MB = free_bytes / (1024 * 1024);
  }
}

// integer log2 for MB free
int iclog2(int x)
{
  int n, c;
  for(n = 0, c = 1; c < x; n++, c <<= 1);
  return n;
}

void rds_message(struct tm *tm)
{
  char disp_short[9], disp_long[65];
  char *name_obd_gps[] = {(char *)"OBD", (char *)"GPS"};
  char *sensor_status_decode = (char *)"XLRY"; // X-no sensors, L-left only, R-right only, Y-both
  char free_MB_2n = ' ';
  SD_status();
  free_MB_2n = '0'+iclog2(free_MB)-1;
  if(free_MB_2n < '0')
    free_MB_2n = '0';
  if(free_MB_2n > '9')
    free_MB_2n = '9';
  if(tm)
  {
    uint16_t year = tm->tm_year + 1900;
    if(speed_ckt < 0 && fast_enough == 0)
    { // no signal and not fast enough (not in tunnel mode)
      sprintf(disp_short, "WAIT  0X");
      sprintf(disp_long, "%s %dMB free %02d:%02d %d km/h WAIT FOR GPS FIX",
        iri99avg2digit,
        free_MB,
        tm->tm_hour, tm->tm_min,
        speed_kmh);
    }
    else
    {
      if(fast_enough)
      {
        sprintf(disp_short, "%3s   0X", iri2digit);
        snprintf(disp_long, sizeof(disp_long), "%.2f,%.2f,%.1fC %.2f,%.2f,%.1fC %s %dMB %02d:%02d %d",
          iri[0], iri20[0], temp[0], iri[1], iri20[1], temp[1], iri99avg2digit,
          free_MB,
          tm->tm_hour, tm->tm_min,
          speed_kmh);
      }
      else // not fast_enough
      {
        sprintf(disp_short, "GO    0X"); // normal
        struct int_latlon ilatlon;
        float flatlon[2];
        nmea2latlon(linenmea, &ilatlon);
        latlon2float(&ilatlon, flatlon);
        snprintf(disp_long, sizeof(disp_long), "%+.6f%c %+.6f%c %.1fC %.1fC %dMB %02d:%02d",
          flatlon[0], flatlon[0] >= 0 ? 'N':'S', flatlon[1], flatlon[1] >= 0 ? 'E':'W', // lat, lon
          temp[0], temp[1],
          free_MB,
          tm->tm_hour, tm->tm_min
        );
      }
      disp_long[sizeof(disp_long)-1] = '\0';
    }
    if(free_MB < 8 || sensor_check_status == 0)
      memcpy(disp_short, "STOP", 4);
    rds.ct(year, tm->tm_mon, tm->tm_mday, tm->tm_hour, tm->tm_min, 0);
  }
  else // NULL pointer
  {
    // null pointer, dummy time
    if(total_bytes)
    {
      sprintf(disp_short, "OFF    X");
      sprintf(disp_long,  "SEARCHING FOR %s SENSOR %s", name_obd_gps[mode_obd_gps], sensor_check_status ? (adxl355_regio ? "ACEL ADXL355" : "GYRO ADXRS290") : "NONE");
    }
    else
    {
      sprintf(disp_short, "SD?    X");
      sprintf(disp_long,  "INSERT SD CARD SENSOR %s", sensor_check_status ? (adxl355_regio ? "ACEL ADXL355" : "GYRO ADXRS290") : "NONE");
      beep_pcm(1024);
    }
    rds.ct(2000, 0, 1, 0, 0, 0);
  }
  disp_short[5] = free_MB_2n;
  //disp_short[6] = name_obd_gps[mode_obd_gps][0];
  disp_short[6] = sensor_status_decode[sensor_check_status];
  disp_short[7] = mode_obd_gps == 0 ? '0' : round_count <= 9 ? '0' + round_count : '9';
  rds.ps(disp_short);
  rds.rt(disp_long);
  Serial.println(disp_short);
  Serial.println(disp_long);
  spi_master_tx_buf[0] = 0; // 0: write ram
  spi_master_tx_buf[1] = 0xD; // addr [31:24] msb to RDS
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  master.transfer(spi_master_tx_buf, 5+(4+16+1)*13); // write RDS binary
  // print to LCD display
  spi_master_tx_buf[1] = 0xC; // addr [31:24] msb to LCD
  spi_master_tx_buf[4] = 23; // addr [ 7: 0] lsb HOME X=22 Y=0
  memset(spi_master_tx_buf+5, 32, 10+64); // clear to end of first line and next 2 lines
  memcpy(spi_master_tx_buf+5, disp_short, 8); // copy 8-byte short RDS message
  int len_disp_long = strlen(disp_long);
  if(len_disp_long <= 30) // only one line
    memcpy(spi_master_tx_buf+5+10, disp_long, len_disp_long); // copy 64-byte long RDS message
  else // 2 lines
  { // each line has 32 bytes in memory, 30 bytes visible
    memcpy(spi_master_tx_buf+5+10, disp_long, 30);
    memcpy(spi_master_tx_buf+5+10+32, disp_long+30, len_disp_long-30);
  }
  master.transfer(spi_master_tx_buf, 5+10+64); // write RDS to LCD
}

void rds_report_ip(struct tm *tm)
{
  static uint8_t tmwait_prev;
  uint8_t tmwait_new = tm->tm_sec/10;
  char disp_short[9], disp_long[65];
  if(tm)
    if(tmwait_new != tmwait_prev)
    {
      tmwait_prev = tmwait_new;
      IPAddress IP = WiFi.localIP();
      String str_IP = WiFi.localIP().toString();
      const char *c_str_IP = str_IP.c_str();
      if((tmwait_new&1)) // print first and second half alternatively
        sprintf(disp_short, "%d.%d.", IP[0], IP[1]);
      else
        sprintf(disp_short, ".%d.%d", IP[2], IP[3]);
      sprintf(disp_long,  "http://%s", c_str_IP);
      rds.ps(disp_short);
      rds.rt(disp_long);
      rds.ct(tm->tm_year + 1900, tm->tm_mon, tm->tm_mday, tm->tm_hour, tm->tm_min, 0);
      Serial.println(disp_short);
      Serial.println(disp_long);
      spi_master_tx_buf[0] = 0; // 0: write ram
      spi_master_tx_buf[1] = 0xD; // addr [31:24] msb
      spi_master_tx_buf[2] = 0; // addr [23:16]
      spi_master_tx_buf[3] = 0; // addr [15: 8]
      spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
      master.transfer(spi_master_tx_buf, 5+(4+16+1)*13); // write RDS binary
      // print to LCD display
      spi_master_tx_buf[1] = 0xC; // addr [31:24] msb to LCD
      spi_master_tx_buf[4] = 23; // addr [ 7: 0] lsb X=22 Y=0
      memset(spi_master_tx_buf+5, 32, 10+64); // clear last 8 char of 1st and next 2 lines
      memcpy(spi_master_tx_buf+5, disp_short, strlen(disp_short)); // copy short RDS message
      memcpy(spi_master_tx_buf+5+10, disp_long, strlen(disp_long)); // copy long RDS message
      master.transfer(spi_master_tx_buf, 5+10+64); // write RDS to LCD
    }
}

void set_fm_freq(void)
{
  spi_master_tx_buf[0] = 0; // 0: write ram
  spi_master_tx_buf[1] = 0x7; // addr [31:24] msb FM freq addr
  spi_master_tx_buf[2] = 0; // addr [23:16] (0:normal, 1:invert)
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  memcpy(spi_master_tx_buf+5, fm_freq, 8);
  master.transfer(spi_master_tx_buf, 5+8); // write to FM freq
  // show freq on LCD
  for(uint8_t i = 0; i < 2; i++)
  {
    spi_master_tx_buf[0] = 0; // 0: write ram
    spi_master_tx_buf[1] = 0xC; // addr [31:24] msb LCD addr
    spi_master_tx_buf[2] = fm_freq_cursor & (1<<i) ? 1 : 0; // addr [23:16] (0:normal, 1:invert)
    spi_master_tx_buf[3] = 0; // addr [15: 8]
    spi_master_tx_buf[4] = 1+(i?7:0); // addr [ 7: 0] lsb HOME X=0,6 Y=0
    sprintf((char *)spi_master_tx_buf+5, "%3d.%02d", fm_freq[i]/1000000, (fm_freq[i]%1000000)/10000);
    master.transfer(spi_master_tx_buf, 5+6); // write to LCD
  }
  // next RDS message will have new AF
  rds.af[0] = fm_freq[0]/100000;
  rds.af[1] = fm_freq[1]/100000;
}

void clr_lcd(void)
{
  spi_master_tx_buf[0] = 0; // 0: write ram
  spi_master_tx_buf[1] = 0xC; // addr [31:24] msb LCD addr
  spi_master_tx_buf[2] = 0; // addr [23:16] (0:normal, 1:invert)
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 1; // addr [ 7: 0] lsb HOME X=0 Y=0
  memset(spi_master_tx_buf+5, 32, 480);
  master.transfer(spi_master_tx_buf, 5+480); // write to LCD
}

// print to LCD screen
void lcd_print(uint8_t x, uint8_t y, uint8_t invert, char *a)
{
  spi_master_tx_buf[0] = 0; // 0: write ram
  spi_master_tx_buf[1] = 0xC; // addr [31:24] msb LCD addr
  spi_master_tx_buf[2] = invert; // addr [23:16] (0:normal, 1:invert)
  spi_master_tx_buf[3] = (y>>3); // addr [15: 8]
  spi_master_tx_buf[4] = 1+x+((y&7)<<5); // addr [ 7: 0] lsb
  int l = strlen(a);
  memcpy(spi_master_tx_buf+5, a, l);
  master.transfer(spi_master_tx_buf, 5+l); // write to LCD
}

void listDir(fs::FS &fs, const char * dirname, uint8_t levels){
    if(card_is_mounted == 0)
      return;
    Serial.printf("Listing directory: %s\n", dirname);

    File root = fs.open(dirname);
    if(!root){
        Serial.println("Failed to open directory");
        return;
    }
    if(!root.isDirectory()){
        Serial.println("Not a directory");
        return;
    }

    File file = root.openNextFile();
    while(file){
        if(file.isDirectory()){
            Serial.print("  DIR : ");
            Serial.println(file.name());
            if(levels){
                listDir(fs, file.name(), levels -1);
            }
        } else {
            Serial.print("  FILE: ");
            Serial.print(file.name());
            Serial.print("  SIZE: ");
            Serial.println(file.size());
        }
        file = root.openNextFile();
    }
}

void mount(void)
{
  if(card_is_mounted)
    return;
  if(!SD_MMC.begin()){
        Serial.println("Card Mount Failed");
        return;
  }

  uint8_t cardType = SD_MMC.cardType();

  if(cardType == CARD_NONE){
        Serial.println("No SD_MMC card attached");
        return;
  }

  Serial.print("SD_MMC Card Type: ");
  if(cardType == CARD_MMC){
        Serial.println("MMC");
  } else if(cardType == CARD_SD){
        Serial.println("SDSC");
  } else if(cardType == CARD_SDHC){
        Serial.println("SDHC");
  } else {
        Serial.println("UNKNOWN");
  }

  uint64_t cardSize = SD_MMC.cardSize() / (1024 * 1024);
  Serial.printf("SD_MMC Card Size: %lluMB\n", cardSize);
  Serial.printf("Total space: %lluMB\n", SD_MMC.totalBytes() / (1024 * 1024));
  Serial.printf("Used space: %lluMB\n", SD_MMC.usedBytes() / (1024 * 1024));
  Serial.printf("Free space: %lluMB\n", (SD_MMC.totalBytes()-SD_MMC.usedBytes()) / (1024 * 1024));

  card_is_mounted = 1;
  logs_are_open = 0;
}

void umount(void)
{
  SD_status();
  SD_MMC.end();
  card_is_mounted = 0;
  logs_are_open = 0;
}

void ls(void)
{
  listDir(SD_MMC, "/", 0);
}

void write_wav_header(void)
{
  uint8_t wavhdr[44] =
  {
    'R', 'I', 'F', 'F',
    0x00, 0x00, 0x00, 0x00, // chunk size bytes (len, including hdr), file growing, not yet known
    'W', 'A', 'V', 'E',
    // subchunk1: fmt
    'f', 'm', 't', ' ',
    0x10, 0x00, 0x00, 0x00, // subchunk 1 size 16 bytes
    0x01, 0x00, // audio format = 1 (PCM)
    0x06, 0x00, // num channels = 6
    0xE8, 0x03, 0x00, 0x00, // sample rate = 1000 Hz
    0xE0, 0x2E, 0x00, 0x00, // byte rate = 12*1000 = 12000 byte/s
    0x0C, 0x00, // block align = 12 bytes
    0x10, 0x00, // bits per sample = 16 bits
    // subchunk2: data    
    'd', 'a', 't', 'a',
    0x00, 0x00, 0x00, 0x00, // chunk size bytes (len), file growing, not yet known       
  };
  file_accel.write(wavhdr, sizeof(wavhdr));
}

/* after write_logs, check beginning middle and end of buffer
   there should be different data from sensor noise.
   all equal data indicate sensor failure
   bit 1: right sensor ok
   bit 0: left  sensor ok
*/
int sensor_check(void)
{
  int retval = 0; // start with both sensors fail
  const int checkat[4] = { // make it 12-even
    SPI_READER_BUF_SIZE*1/8 - SPI_READER_BUF_SIZE*1/8%12,
    SPI_READER_BUF_SIZE*2/8 - SPI_READER_BUF_SIZE*2/8%12,
    SPI_READER_BUF_SIZE*3/8 - SPI_READER_BUF_SIZE*3/8%12,
    SPI_READER_BUF_SIZE*4/8 - SPI_READER_BUF_SIZE*4/8%12 - 12,
  }; // list of indexes to check (0 not included)
  int lr[2] = {6, 12}; // l, r index of sensors in rx buf to check
  uint8_t v0[6], v[6]; // sensor readings

  int i, j, k;

  for(i = 0; i < 2; i++) // lr index
  {
    memcpy(v0, spi_master_rx_buf + lr[i], 6);
    // remove LSB
    for(k = 0; k < 6; k += 2)
      v0[k] |= 1;
    for(j = 0; j < 4; j++) // checkat index
    {
      memcpy(v, spi_master_rx_buf + lr[i] + checkat[j], 6);
      // remove LSB
      for(k = 0; k < 6; k += 2)
        v[k] |= 1;
      if(memcmp(v, v0, 6) != 0)
        retval |= 1<<i;
    }
  }
  return retval;
}

void store_last_sensor_reading(void)
{
  const int offset = SPI_READER_BUF_SIZE*4/8 - SPI_READER_BUF_SIZE*4/8%12 - 12-6;
  memcpy(last_sensor_reading, spi_master_rx_buf + offset, sizeof(last_sensor_reading));
}

void generate_filename_wav(struct tm *tm)
{
  #if 1
  sprintf(filename_data, (char *)"/profilog/data/%04d%02d%02d-%02d%02d.wav",
    tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
  #else // one file per day
  sprintf(filename_data, (char *)"/profilog/data/%04d%02d%02d.wav",
    tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday);
  #endif
}

void open_log_wav(struct tm *tm)
{
  generate_filename_wav(tm);
  #if 1
  //SD_MMC.remove(filename_data);
  file_accel = SD_MMC.open(filename_data, FILE_APPEND);
  // check appending file position (SEEK_CUR) and if 0 then write header
  if(file_accel.position() == 0)
    write_wav_header();
  #else
  SD_MMC.remove(filename_data);
  SD_MMC.remove((char *)"/profilog/data/accel.wav");
  file_accel = SD_MMC.open(filename_data, FILE_WRITE);
  write_wav_header();
  #endif
  #if 1
  Serial.print(filename_data);
  Serial.print(" @");
  Serial.println(file_accel.position());
  #endif
}

void flush_log_wav(void)
{
  file_accel.flush();
}

void write_log_wav(void)
{
  static uint8_t prev_half = 0;
  uint8_t half;
  uint16_t ptr;
  int retval = -1;

  ptr = (SPI_READER_BUF_SIZE + spi_slave_ptr() - 2) % SPI_READER_BUF_SIZE; // written content is 2 bytes behind pointer
  half = ptr >= SPI_READER_BUF_SIZE/2;
  if(half != prev_half)
  {
    spi_slave_read(half ? 0 : SPI_READER_BUF_SIZE/2, SPI_READER_BUF_SIZE/2);
    if(logs_are_open && fast_enough)
    {
      file_accel.write(spi_master_rx_buf+6, SPI_READER_BUF_SIZE/2);
      #if 0
      // print buffer ptr
      Serial.print("ptr ");
      Serial.println(ptr, DEC);
      #endif
    }
    prev_half = half;
    sensor_check_status = sensor_check();
    store_last_sensor_reading();
    //Serial.println(sensor_check_status);
  }
}

// write constant xyz value from last reading
// with the string mixed in
// string len: max 20 chars
void write_string_to_wav(char *a)
{
  uint8_t wsw[255], c;
  int j;

  if(logs_are_open == 0)
    return;
  if((log_wav_kml&1) == 0)
    return;

  for(j = 0; *a != 0; a++, j+=12)
  {
    c = *a;
    wsw[j     ] = (last_sensor_reading[ 0] & 0xFE) | (c & 1); c >>= 1;
    wsw[j +  1] =  last_sensor_reading[ 1];
    wsw[j +  2] = (last_sensor_reading[ 2] & 0xFE) | (c & 1); c >>= 1;
    wsw[j +  3] =  last_sensor_reading[ 3];
    wsw[j +  4] = (last_sensor_reading[ 4] & 0xFE) | (c & 1); c >>= 1;
    wsw[j +  5] =  last_sensor_reading[ 5];
    wsw[j +  6] = (last_sensor_reading[ 6] & 0xFE) | (c & 1); c >>= 1;
    wsw[j +  7] =  last_sensor_reading[ 7];
    wsw[j +  8] = (last_sensor_reading[ 8] & 0xFE) | (c & 1); c >>= 1;
    wsw[j +  9] =  last_sensor_reading[ 9];
    wsw[j + 10] = (last_sensor_reading[10] & 0xFE) | (c & 1);
    wsw[j + 11] =  last_sensor_reading[11];
  }
  file_accel.write(wsw, j);
}

void write_last_nmea(void)
{
  if (check_nmea_crc(lastnmea))
  {
    File file_lastnmea = SD_MMC.open(filename_lastnmea, FILE_WRITE);
    file_lastnmea.write((uint8_t *)lastnmea, strlen(lastnmea));
    file_lastnmea.write('\n');
    Serial.print("write last nmea: ");
    Serial.println(lastnmea);
    file_lastnmea.close();
  }
  #if 0 // debug
  else
  {
    Serial.print("last nmea not written\nbad crc:");
    Serial.println(lastnmea);
  }
  #endif
}

// file creation times should work with this
void set_system_time(time_t seconds_since_1980)
{
  timeval epoch = {seconds_since_1980, 0};
  const timeval *tv = &epoch;
  timezone utc = {0, 0};
  const timezone *tz = &utc;
  settimeofday(tv, tz);
}

uint8_t datetime_is_set = 0;
void set_date_from_tm(struct tm *tm)
{
  uint16_t year;
  uint8_t month, day, h, m, s;
  time_t t_of_day;
  if (datetime_is_set)
    return;
  t_of_day = mktime(tm);
  set_system_time(t_of_day);
  datetime_is_set = 1;
#if 0
  char *b = nthchar(a, 9, ',');
  if (b == NULL)
    return;
  year  = (b[ 5] - '0') * 10 + (b[ 6] - '0') + 2000;
  month = (b[ 3] - '0') * 10 + (b[ 4] - '0');
  day   = (b[ 1] - '0') * 10 + (b[ 2] - '0');
  h     = (a[ 7] - '0') * 10 + (a[ 8] - '0');
  m     = (a[ 9] - '0') * 10 + (a[10] - '0');
  s     = (a[11] - '0') * 10 + (a[12] - '0');
#endif
#if 1
  year  = tm->tm_year + 1900;
  month = tm->tm_mon  + 1;
  day   = tm->tm_mday;
  h     = tm->tm_hour;
  m     = tm->tm_min;
  s     = tm->tm_sec;
  char pr[80];
  //sprintf(pr, "datetime %04d-%02d-%02d %02d:%02d:%02d", year, month, day, h, m, s);
  //Serial.println(pr);
#endif
}

void read_last_nmea(void)
{
  File file_lastnmea = SD_MMC.open(filename_lastnmea, FILE_READ);
  //file_lastnmea.readBytes(lastnmea, strlen(lastnmea));
  if(!file_lastnmea)
    return;
  String last_nmea_line = file_lastnmea.readStringUntil('\n');
  strcpy(lastnmea, last_nmea_line.c_str());
  Serial.print("read last nmea: ");
  Serial.println(lastnmea);
  file_lastnmea.close();
  if(check_nmea_crc(lastnmea))
  {
    if (nmea2tm(lastnmea, &tm))
      set_date_from_tm(&tm);
    nmea2latlon(lastnmea, &last_latlon); // parsing should not spoil lastnmea content
  }
  else
    Serial.println("read last nmea bad crc");
  #if 0
  char latlon_spr[120];
  sprintf(latlon_spr, "parsed: %02d%02d.%06d %03d%02d.%06d",
    last_latlon.lat_deg, last_latlon.lat_umin / 1000000, last_latlon.lat_umin % 1000000,
    last_latlon.lon_deg, last_latlon.lon_umin / 1000000, last_latlon.lon_umin % 1000000
  );
  Serial.println(latlon_spr);
  #endif
  // lastnmea[0] = 0; // prevent immediate next write, not needed as parsing does similar
}

void write_fmfreq(void)
{
  char fmfreq[32];
  if(card_is_mounted == 0)
    return;
  File file_fmfreq = SD_MMC.open(filename_fmfreq, FILE_WRITE);
  if(!file_fmfreq)
    return;
  sprintf(fmfreq, "%09d %09d\n", fm_freq[0], fm_freq[1]);
  file_fmfreq.write((uint8_t *)fmfreq, 20);
  file_fmfreq.close();
  Serial.print("write fmfreq: ");
  Serial.print(fmfreq);
}

void read_fmfreq(void)
{
  if(card_is_mounted == 0)
    return;
  File file_fmfreq = SD_MMC.open(filename_fmfreq, FILE_READ);
  if(!file_fmfreq)
    return;
  String fmfreq_line = file_fmfreq.readStringUntil('\n');
  file_fmfreq.close();
  fm_freq[0] = strtol(fmfreq_line.substring( 0, 9).c_str(), NULL, 10);
  fm_freq[1] = strtol(fmfreq_line.substring(10,19).c_str(), NULL, 10);
  Serial.print("read fmfreq: ");
  Serial.print(fm_freq[0]);
  Serial.print(" ");
  Serial.print(fm_freq[1]);
  Serial.println(" Hz");
}

void write_tag(char *a)
{
  int i;
  spi_master_tx_buf[0] = 0; // 0: write ram
  spi_master_tx_buf[1] = 6; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  for(i = 5; *a != 0; i++, a++)
    spi_master_tx_buf[i] = *a; // write tag char
  master.transfer(spi_master_tx_buf, i); // write tag string
}

// repeatedly call this to refill buffer with PCM data from file
// play max n bytes (samples) from open PCM file
// return number of bytes to be played for this buffer refill
int play_pcm(int n)
{
  if(pcm_is_open == 0)
    return 0;
  if(n > SPI_READER_BUF_SIZE)
    n = SPI_READER_BUF_SIZE;
  int a = file_pcm.available(); // number of bytes available
  if(a > 0 && a < n)
    n = a; // clamp n to available bytes
  if(a < 0)
    n = 0;
  if(n)
  {
    spi_master_tx_buf[0] = 0; // 0: write ram
    spi_master_tx_buf[1] = 5; // addr [31:24] msb
    spi_master_tx_buf[2] = 0; // addr [23:16]
    spi_master_tx_buf[3] = 0; // addr [15: 8]
    spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
    file_pcm.read(spi_master_tx_buf+5, n);
    master.transfer(spi_master_tx_buf, n+5); // write pcm to play
    #if 0
    // debug print sending PCM packets
    Serial.print("PCM ");
    Serial.println(n, DEC);
    #endif
  }
  if(n == a)
  {
    file_pcm.close();
    pcm_is_open = 0;
    #if 0
    Serial.println("PCM done");
    #endif
  }
  return n;
}

int open_pcm(char *wav)
{
  if(pcm_is_open)
    return 0;
  int n = 3584; // bytes to play for initiall buffer fill
  // to generate wav files:
  // espeak-ng -v hr -f speak.txt -w speak.wav; sox speak.wav --no-dither -r 11025 -b 8 output.wav reverse trim 1s reverse
  // "--no-dither" reduces noise
  // "-r 11025 -b 8" is sample rate 11025 Hz, 8 bits per sample
  // "reverse trim 1s reverse" cuts off 1 sample from the end, to avoid click
  file_pcm = SD_MMC.open(wav, FILE_READ);
  if(file_pcm)
  {
    file_pcm.seek(44); // skip header to get data
    pcm_is_open = 1;
    play_pcm(n); // initially fill the play buffer, max buffer is 4KB
  }
  else
  {
    Serial.print("can't open file ");
    pcm_is_open = 0;
    n = 0;
  }
  Serial.println(wav); // print which file is playing now
  return n;
}

// play 8-bit PCM beep sample
void beep_pcm(int n)
{
  int i;
  int16_t v;
  spi_master_tx_buf[0] = 0; // 0: write ram
  spi_master_tx_buf[1] = 5; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  for(v = 0, i = 0; i < n; i++)
  {
    v += ((i+4)&8) ? -1 : 1;
    spi_master_tx_buf[i+5] = v*16; // create wav
  }
  master.transfer(spi_master_tx_buf, n+5); // write pcm to play
}

// write n bytes to 52-byte RDS memory
void write_rds(uint8_t *a, int n)
{
  int i;
  spi_master_tx_buf[0] = 0; // 0: write ram
  spi_master_tx_buf[1] = 0xD; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  for(i = 0; i < n; i++, a++)
    spi_master_tx_buf[i+5] = *a; // write RDS byte
  master.transfer(spi_master_tx_buf, n+5); // write tag string
}


// this function doesn't work
// seek() is not working
void finalize_wav_header(void)
{
  uint32_t pos = file_accel.position();
  uint32_t subchunk2size = pos - 44;
  uint8_t subchunk2size_bytes[4] = {(uint8_t)subchunk2size, (uint8_t)(subchunk2size>>8), (uint8_t)(subchunk2size>>16), (uint8_t)(subchunk2size>>24)};
  uint32_t chunksize = pos - 8;
  uint8_t chunksize_bytes[4] = {(uint8_t)chunksize, (uint8_t)(chunksize>>8), (uint8_t)(chunksize>>16), (uint8_t)(chunksize>>24)};
  // FIXME file_accel.seek() is not working
  file_accel.seek(4);
  file_accel.write(chunksize_bytes, 4);
  file_accel.seek(40);
  file_accel.write(subchunk2size_bytes, 4);
  Serial.print("finalization hdr position ");
  Serial.print(file_accel.position(), DEC);
  Serial.print(" logs finalized at pos ");
  Serial.println(pos, DEC);  
}

void close_log_wav(void)
{
  logs_are_open = 0;
  //finalize_wav_header();
  file_accel.close();
}

void write_kml_header(struct tm *tm)
{
  char name[23];
  snprintf(name, sizeof(name), "PROFILOG %04d%02d%02d-%02d%02d",
    tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
  kml_header(name);
  file_kml.write((uint8_t *)kmlbuf, strlen(kmlbuf));
}

void write_stat_arrows(void)
{
  if(logs_are_open == 0)
    return;
  if((log_wav_kml&2) == 0)
    return;

  char timestamp[23] = "2000-01-01T00:00:00.0Z";
  nmea2kmltime(lastnmea, timestamp);
  kml_buf_init();
  #if 0
  // debug write some dummy arrows
  for(int i = 0; i < 10; i++)
  {
    x_kml_arrow->lon       = 16.0+0.001*i;
    x_kml_arrow->lat       = 46.0;
    x_kml_arrow->value     = 1.0;
    x_kml_arrow->left      = 1.1;
    x_kml_arrow->right     = 1.2;
    x_kml_arrow->left_stdev  =  0.1;
    x_kml_arrow->right_stdev =  0.1;
    x_kml_arrow->n         = i;
    x_kml_arrow->heading   = 0.0;
    x_kml_arrow->speed_min_kmh = 80.0;
    x_kml_arrow->speed_max_kmh = 80.0;
    x_kml_arrow->timestamp = timestamp;
    kml_arrow(x_kml_arrow);
    file_kml.write((uint8_t *)kmlbuf, str_kml_arrow_len);
  }
  #endif
  printf("writing %d stat arrows to kml\n", s_stat.wr_snap_ptr);
  for(int i = 0; i < s_stat.wr_snap_ptr; i++)
  {
    x_kml_arrow->lon       = (float)(s_stat.snap_point[i].xm) / (float)lon2gridm;
    x_kml_arrow->lat       = (float)(s_stat.snap_point[i].ym) / (float)lat2gridm;
    x_kml_arrow->value     = (s_stat.snap_point[i].sum_iri[0][0]+s_stat.snap_point[i].sum_iri[0][1]) / (2*s_stat.snap_point[i].n);
    x_kml_arrow->left      =  s_stat.snap_point[i].sum_iri[0][0] / s_stat.snap_point[i].n;
    x_kml_arrow->right     =  s_stat.snap_point[i].sum_iri[0][1] / s_stat.snap_point[i].n;
    x_kml_arrow->left_stdev  =  0.0;
    x_kml_arrow->right_stdev =  0.0;
    uint8_t n = s_stat.snap_point[i].n;
    if(n > 0)
    {
      float sum1_left  = s_stat.snap_point[i].sum_iri[0][0];
      float sum2_left  = s_stat.snap_point[i].sum_iri[1][0];
      float sum1_right = s_stat.snap_point[i].sum_iri[0][1];
      float sum2_right = s_stat.snap_point[i].sum_iri[1][1];
      x_kml_arrow->left_stdev  =  sqrt(fabs( n*sum2_left  - sum1_left  * sum1_left  ))/n;
      x_kml_arrow->right_stdev =  sqrt(fabs( n*sum2_right - sum1_right * sum1_right ))/n;
    }
    x_kml_arrow->n         = n;
    x_kml_arrow->heading   = (float)(s_stat.snap_point[i].heading * (360.0/65536));
    x_kml_arrow->speed_min_kmh = s_stat.snap_point[i].vmin;
    x_kml_arrow->speed_max_kmh = s_stat.snap_point[i].vmax;
    x_kml_arrow->timestamp = timestamp;
    kml_arrow(x_kml_arrow);
    file_kml.write((uint8_t *)kmlbuf, str_kml_arrow_len);
  }
}

// finalize kml file, no more writes after this
void write_kml_footer(void)
{
  file_kml.write((uint8_t *)str_kml_footer_simple, strlen(str_kml_footer_simple));
}

// force = 0: if kml buffer is full write
// force = 1: write immediately what is in the buffer
void write_log_kml(uint8_t force)
{
  //printf("kmlbuf_pos %d\n", kmlbuf_pos);
  if(logs_are_open && fast_enough)
  {
    if(
      (force == 0 && kmlbuf_pos < kmlbuf_len-str_kml_line_len-1) // write if force or buffer full
    ||(kmlbuf_pos <= kmlbuf_start) // nothing to write
    )
      return;
    file_kml.write((uint8_t *)kmlbuf+kmlbuf_start, kmlbuf_pos-kmlbuf_start);
    kmlbuf_pos = str_kml_arrow_len; // consumed, default start next write past arrow
    kmlbuf_start = str_kml_arrow_len; // same as kmlbuf_pos default write to file from this point
  }
}

void generate_filename_kml(struct tm *tm)
{
  #if 1
  sprintf(filename_data, (char *)"/profilog/data/%04d%02d%02d-%02d%02d.kml",
    tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
  #else // one file per day
  sprintf(filename_data, (char *)"/profilog/data/%04d%02d%02d.kml",
    tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday);
  #endif
}

void open_log_kml(struct tm *tm)
{
  generate_filename_kml(tm);
  file_kml = SD_MMC.open(filename_data, FILE_APPEND);
  // check appending file position (SEEK_CUR) and if 0 then write header
  if(file_kml.position() == 0)
    write_kml_header(tm);
  kml_buf_init(); // fill kml buffer with arrow and line content
  #if 1
  Serial.print(filename_data);
  Serial.print(" @");
  Serial.println(file_kml.position());
  #endif
}

void close_log_kml(void)
{
  file_kml.close();
}

void spi_slave_test(void)
{
  static uint8_t count = 0;
  uint16_t wptr;
  #if 0
  // begin spi slave test (use SPI_MODE3)
  spi_master_tx_buf[0] = 0; // 0: write ram
  spi_master_tx_buf[1] = 0; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  spi_master_tx_buf[5] = 0x11; // data
  spi_master_tx_buf[6] = 0x22; // data
  spi_master_tx_buf[7] = 0x33; // data
  spi_master_tx_buf[8] = count++; // data
  master.transfer(spi_master_tx_buf, 9); // write
  #endif // end writing
  wptr = spi_slave_ptr();
  spi_master_tx_buf[0] = 1; // 1: read ram
  spi_master_tx_buf[1] = 0; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  spi_master_tx_buf[5] = 0; // dummy
  master.transfer(spi_master_tx_buf, spi_master_rx_buf, 30); // read
  for(int i = 6; i < 30; i++)
  {
    Serial.print(spi_master_rx_buf[i], HEX);
    Serial.print(" ");
  }
  Serial.print(wptr, DEC);
  Serial.println("");
  // end spi slave test
}

void spi_direct_test(void)
{
  // begin debug reading ID and printing
  spi_master_tx_buf[0] = ADXL355_DEVID_AD*2+1; // read ID (4 bytes expected)
  //digitalWrite(PIN_CSN, 0);
  master.transfer(spi_master_tx_buf, spi_master_rx_buf, 5);
  //digitalWrite(PIN_CSN, 1);
  for(int i = 1; i <= 4; i++)
  {
    Serial.print(spi_master_rx_buf[i], HEX);
    Serial.print(" ");
  }
  Serial.println("");
  // end debug reading ID and printing
}

void parse_mac(uint8_t *mac, String a)
{
  for(int i = 0; i < 6; i++)
    mac[i] = strtol(a.substring(i*3,i*3+2).c_str(), NULL, 16);
}

void check_gps_obd_config()
{
  // check existence of OBD config
  gps_obd_configured = OBD_NAME.length() > 0 ? 1 : 0;
  if(gps_obd_configured == 0)
    for(uint8_t i = 0; i < 6; i++)
      if(OBD_MAC[i])
        gps_obd_configured = 1;

  // check existence of GPS config
  gps_obd_configured |= GPS_NAME.length() > 0 ? 2 : 0;
  if((gps_obd_configured & 2) == 0)
    for(uint8_t i = 0; i < 6; i++)
      if(GPS_MAC[i])
        gps_obd_configured |= 2;
}

void read_cfg(void)
{
  char *filename_cfg = (char *)"/profilog/config/profilog.cfg";
  file_cfg = SD_MMC.open(filename_cfg, FILE_READ);
  int linecount = 0;
  Serial.print("*** open ");
  Serial.println(filename_cfg);
  int ap_n = 0; // AP counter
  while(file_cfg.available())
  {
    String cfgline = file_cfg.readStringUntil('\n');
    linecount++;
    if(cfgline.length() < 2) // skip empty and short lines
      continue;
    if(cfgline[0] == '#') // skip comments
      continue;
    int delimpos = cfgline.indexOf(':'); // delimiter position
    if(delimpos < 2) // skip lines without proper ":" delimiter
      continue;
    String varname = cfgline.substring(0, delimpos);
    varname.trim(); // inplace trim leading and trailing whitespace
    String varvalue = cfgline.substring(delimpos+1); // to end of line
    varvalue.trim(); // inplace trim leading and trailing whitespace
    if     (varname.equalsIgnoreCase("ap_pass" )) {if(ap_n<AP_MAX) AP_PASS[ap_n++] = varvalue; }
    else if(varname.equalsIgnoreCase("dns_host")) DNS_HOST = varvalue;
    else if(varname.equalsIgnoreCase("gps_name")) GPS_NAME = varvalue;
    else if(varname.equalsIgnoreCase("gps_mac" )) parse_mac(GPS_MAC, varvalue);
    else if(varname.equalsIgnoreCase("gps_pin" )) GPS_PIN  = varvalue;
    else if(varname.equalsIgnoreCase("obd_name")) OBD_NAME = varvalue;
    else if(varname.equalsIgnoreCase("obd_mac" )) parse_mac(OBD_MAC, varvalue);
    else if(varname.equalsIgnoreCase("obd_pin" )) OBD_PIN  = varvalue;
    else if(varname.equalsIgnoreCase("log_mode")) log_wav_kml = strtol(varvalue.c_str(), NULL,10);
    else if(varname.equalsIgnoreCase("red_iri" )) red_iri = strtof(varvalue.c_str(), NULL);
    else if(varname.equalsIgnoreCase("g_range" )) G_RANGE = strtol(varvalue.c_str(), NULL,10);
    else if(varname.equalsIgnoreCase("filter_adxl355" )) FILTER_ADXL355_CONF  = strtol(varvalue.c_str(), NULL,10);
    else if(varname.equalsIgnoreCase("filter_adxrs290")) FILTER_ADXRS290_CONF = strtol(varvalue.c_str(), NULL,10);
    else if(varname.equalsIgnoreCase("tl_offset_adxl355" )) T_OFFSET_ADXL355_CONF[0]  = strtof(varvalue.c_str(), NULL);
    else if(varname.equalsIgnoreCase("tl_slope_adxl355" )) T_SLOPE_ADXL355_CONF[0]  = strtof(varvalue.c_str(), NULL);
    else if(varname.equalsIgnoreCase("tr_offset_adxl355" )) T_OFFSET_ADXL355_CONF[1]  = strtof(varvalue.c_str(), NULL);
    else if(varname.equalsIgnoreCase("tr_slope_adxl355" )) T_SLOPE_ADXL355_CONF[1]  = strtof(varvalue.c_str(), NULL);
    else if(varname.equalsIgnoreCase("tl_offset_adxrs290")) T_OFFSET_ADXRS290_CONF[0] = strtof(varvalue.c_str(), NULL);
    else if(varname.equalsIgnoreCase("tl_slope_adxrs290")) T_SLOPE_ADXRS290_CONF[0] = strtof(varvalue.c_str(), NULL);
    else if(varname.equalsIgnoreCase("tr_offset_adxrs290")) T_OFFSET_ADXRS290_CONF[1] = strtof(varvalue.c_str(), NULL);
    else if(varname.equalsIgnoreCase("tr_slope_adxrs290")) T_SLOPE_ADXRS290_CONF[1] = strtof(varvalue.c_str(), NULL);
    else if(varname.equalsIgnoreCase("kmh_report1")) KMH_REPORT1 = strtol(varvalue.c_str(), NULL,10);
    else if(varname.equalsIgnoreCase("m_report1")) MM_REPORT1 = 1000*strtol(varvalue.c_str(), NULL,10);
    else if(varname.equalsIgnoreCase("m_report2")) MM_REPORT2 = 1000*strtol(varvalue.c_str(), NULL,10);
    else if(varname.equalsIgnoreCase("kmh_start")) KMH_START = strtol(varvalue.c_str(), NULL,10);
    else if(varname.equalsIgnoreCase("kmh_stop")) KMH_STOP = strtol(varvalue.c_str(), NULL,10);
    else if(varname.equalsIgnoreCase("kmh_btn" )) KMH_BTN = strtol(varvalue.c_str(), NULL,10);
    else
    {
      Serial.print(filename_cfg);
      Serial.print(": error in line ");
      Serial.println(linecount);
    }
  }
  char macstr[80];
  Serial.print("GPS_NAME : "); Serial.println(GPS_NAME);
  sprintf(macstr, "GPS_MAC  : %02X:%02X:%02X:%02X:%02X:%02X",
    GPS_MAC[0], GPS_MAC[1], GPS_MAC[2], GPS_MAC[3], GPS_MAC[4], GPS_MAC[5]);
  Serial.println(macstr);
  Serial.print("GPS_PIN  : "); Serial.println(GPS_PIN);
  Serial.print("OBD_NAME : "); Serial.println(OBD_NAME);
  sprintf(macstr, "OBD_MAC  : %02X:%02X:%02X:%02X:%02X:%02X",
    OBD_MAC[0], OBD_MAC[1], OBD_MAC[2], OBD_MAC[3], OBD_MAC[4], OBD_MAC[5]);
  Serial.println(macstr);
  Serial.print("OBD_PIN  : "); Serial.println(OBD_PIN);
  for(int i = 0; i < ap_n; i++)
  { Serial.print("AP_PASS  : "); Serial.println(AP_PASS[i]); }
  Serial.print("DNS_HOST : "); Serial.println(DNS_HOST);
  Serial.print("LOG_MODE : "); Serial.println(log_wav_kml);
  char chr_red_iri[20]; sprintf(chr_red_iri, "%.1f", red_iri);
  Serial.print("RED_IRI  : "); Serial.println(chr_red_iri);
  Serial.print("G_RANGE  : "); Serial.println(G_RANGE);
  Serial.print("FILTER_ADXL355     : "); Serial.println(FILTER_ADXL355_CONF);
  Serial.print("FILTER_ADXRS290    : "); Serial.println(FILTER_ADXRS290_CONF);
  for(int i = 0; i < 2; i++)
  {
    char lr = i ? 'R' : 'L';
    sprintf(macstr, "T%c_OFFSET_ADXL355  : %.1f", lr, T_OFFSET_ADXL355_CONF[i]);
    Serial.println(macstr);
    sprintf(macstr, "T%c_SLOPE_ADXL355   : %.1f", lr, T_SLOPE_ADXL355_CONF[i]);
    Serial.println(macstr);
    sprintf(macstr, "T%c_OFFSET_ADXRS290 : %.1f", lr, T_OFFSET_ADXRS290_CONF[i]);
    Serial.println(macstr);
    sprintf(macstr, "T%c_SLOPE_ADXRS290  : %.1f", lr, T_SLOPE_ADXRS290_CONF[i]);
    Serial.println(macstr);
  }
  Serial.print("M_REPORT1   : "); Serial.println(MM_REPORT1/1000);
  Serial.print("M_REPORT2   : "); Serial.println(MM_REPORT2/1000);
  Serial.print("KMH_REPORT1 : "); Serial.println(KMH_REPORT1);
  Serial.print("KMH_START   : "); Serial.println(KMH_START);
  Serial.print("KMH_STOP    : "); Serial.println(KMH_STOP);
  Serial.print("KMH_BTN     : "); Serial.println(KMH_BTN);
  Serial.print("*** close ");
  Serial.println(filename_cfg);
  file_cfg.close();
  check_gps_obd_config();
}

void open_logs(struct tm *tm)
{
  if(logs_are_open != 0)
    return;
  if(log_wav_kml&1)
    open_log_wav(tm);
  if(log_wav_kml&2)
    open_log_kml(tm);
  logs_are_open = 1;
}

void write_logs()
{
  if(log_wav_kml&1)
    write_log_wav();
  //if(log_wav_kml&2)
  //  write_log_kml(0); // write logs, no force
}

void flush_logs()
{
  if(logs_are_open == 0)
    return;
  if(log_wav_kml&1)
    flush_log_wav();
}

void close_logs()
{
  if(logs_are_open == 0)
    return;
  if(log_wav_kml&1)
    close_log_wav();
  if(log_wav_kml&2)
    close_log_kml();
  logs_are_open = 0;
}

void finalize_kml(File &kml, String file_name)
{
  kml.seek(kml.size() - 7);
  String file_end = kml.readString();
  if(file_end != "</kml>\n")
  {
    Serial.print("Finalizing ");
    Serial.println(file_name);
    // kml.close(); // crash with arduino esp32 v2.0.2
    File wkml = SD_MMC.open(file_name, FILE_APPEND);
    wkml.write((uint8_t *)str_kml_footer_simple, strlen(str_kml_footer_simple));
    wkml.close();
  }
}

// finalize everyting except
// the file that would be opened
// as session based on time (tm)
void finalize_data(struct tm *tm){
    if(card_is_mounted == 0)
      return;
    if(logs_are_open)
      return;
    const char *dirname = (char *)"/profilog/data";
    Serial.printf("Finalizing directory: %s\n", dirname);

    File root = SD_MMC.open(dirname);
    if(!root){
        Serial.println("Failed to open directory");
        return;
    }
    if(!root.isDirectory()){
        Serial.println("Not a directory");
        return;
    }
    char todaystr[10];
    sprintf(todaystr, "%04d%02d%02d", 1900+tm->tm_year, 1+tm->tm_mon, tm->tm_mday);
    Serial.println(todaystr); // debug
    int lcd_n=0; // counts printed LCD lines
    const int max_lcd_n=12;
    generate_filename_kml(tm);
    File file = root.openNextFile();
    while(file){
        if(file.isDirectory()){
            Serial.print("  DIR : ");
            Serial.println(file.name());
        } else {
            Serial.print("  FILE: ");
            Serial.print(file.name());
            Serial.print("  SIZE: ");
            Serial.println(file.size());
            char *is_kml = strstr(file.name(),".kml");
            if(is_kml)
            {
              String full_path = String(file.name());
              if((file.name())[0] != '/')
                full_path = String(dirname) + "/" + String(file.name());
              if(strcmp(full_path.c_str(), filename_data) != 0) // different name
                finalize_kml(file, full_path);
            }
            // print on LCD
            char *is_wav = strstr(file.name(),".wav");
            char *is_today = strstr(file.name(),todaystr);
            if(is_today)
            {
              int wrap_lcd_n = lcd_n % max_lcd_n; // wraparound last N lines
              char *txbufptr = (char *)spi_master_tx_buf+5+(wrap_lcd_n<<5);
              memset(txbufptr, 32, 32); // clear line
              strcpy(txbufptr, is_today);
              if(is_wav)
                sprintf(txbufptr+17, " %4d min", file.size()/720000);
              if(is_kml)
                sprintf(txbufptr+17, " %4d MB", file.size()/(1024*1024));
              lcd_n++;
            }
        }
        file = root.openNextFile();
    }
    // write to LCD
    if(lcd_n)
    {
      int limit_lcd_n = lcd_n > max_lcd_n ? max_lcd_n : lcd_n;
      spi_master_tx_buf[0] = 0; // 0: write ram
      spi_master_tx_buf[1] = 0xC; // addr [31:24] msb LCD addr
      spi_master_tx_buf[2] = 0; // addr [23:16] (0:normal, 1:invert)
      spi_master_tx_buf[3] = 0; // addr [15: 8]
      spi_master_tx_buf[4] = 1+(3<<5); // addr [ 7: 0] lsb HOME X=0 Y=3
      master.transfer(spi_master_tx_buf, 5+(limit_lcd_n<<5)); // write to LCD
    }
}
