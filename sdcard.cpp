#include "pins.h"
#include "sdcard.h"
#include "adxl355.h"
#include "nmea.h"
#include <sys/time.h>

// TODO
// too much of various code is put into this module
// big cleanup needed, code from here should be distributed
// to multiple modules for readability
// (sdcard, adxl master, adxl reader, audio player, ascii tagger)

RDS rds;

// Manage Libraries -> ESP32DMASPI
#include <ESP32DMASPIMaster.h> // Version 0.1.0 tested

ESP32DMASPI::Master master;
uint8_t* spi_master_tx_buf;
uint8_t* spi_master_rx_buf;
static const uint32_t BUFFER_SIZE = SPI_READER_BUF_SIZE+6;

// config file parsing
uint8_t GPS_MAC[6], OBD_MAC[6];
String  GPS_NAME, GPS_PIN, OBD_NAME, OBD_PIN, AP_NAME, AP_PASS, DNS_HOST;

File file_kml, file_accel, file_pcm, file_cfg;
char filename_data[256] = "/profilog/data/accel.wav";
char *filename_lastnmea = "/profilog/var/lastnmea.txt";
char lastnmea[256]; // here is read content from filename_lastnmea
int card_is_mounted = 0;
int logs_are_open = 0;
int pcm_is_open = 0;
int sensor_check_status = 0;
int speed_ckt = -1; // centi-knots speed (kt*100)
int speed_mms = -1; // mm/s speed
int speed_kmh = -1; // km/h speed
int fast_enough = 0; // for speed logging hysteresis
int mode_obd_gps = 0; // alternates 0:OBD and 1:GPS
float iri[2], iriavg;
char iri2digit[4] = "0.0";
int_latlon last_latlon; // degrees and microminutes
struct tm tm, tm_session; // tm_session gives new filename_data when reconnected
uint8_t log_wav_kml = 3; // 1-wav 2-kml 3-both

// SD status
size_t total_bytes, used_bytes, free_bytes, free_MB;

void adxl355_write_reg(uint8_t a, uint8_t v)
{
  spi_master_tx_buf[0] = a*2; // write reg addr a
  spi_master_tx_buf[1] = v;
  //digitalWrite(PIN_CSN, 0);
  master.transfer(spi_master_tx_buf, 2);
  //digitalWrite(PIN_CSN, 1);
}

uint8_t adxl355_read_reg(uint8_t a)
{
  spi_master_tx_buf[0] = a*2+1; // read reg addr a
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

void adxl355_init(void)
{
  Serial.println("initializing ADXL");
  adxl355_ctrl(2); // request core direct mode
  delay(2); // wait for request to be accepted
  for(int i = 0; i < 4; i++)
    adxl355_read_reg(i);
  adxl355_write_reg(POWER_CTL, 0); // turn device ON
  // i=1-3 range 1:+-2g, 2:+-4g, 3:+-8g
  // high speed i2c, INT1,INT2 active high
  //delay(100);
  adxl355_write_reg(RANGE, 1);
  // sample rate i=0-10, 4kHz/2^i, 0:4kHz ... 10:3.906Hz
  //delay(100);
  adxl355_write_reg(FILTER, 0);
  // sync: 0:internal, 2:external sync with interpolation, 5:external clk/sync < 1066 Hz no interpolation, 6:external clk/sync with interpolation
  //delay(100);
  adxl355_write_reg(SYNC, 0xC0 | 2); // 0: internal, 2: takes external sync to drdy pin
  adxl355_ctrl(0); // request core indirect mode
  delay(2); // wait for direct mode to finish
}

uint8_t adxl355_available(void)
{
  // read number of entries in the fifo
  spi_master_tx_buf[0] = FIFO_ENTRIES*2+1; // FIFO_ENTRIES read request
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
    spi_master_tx_buf[0] = FIFO_DATA*2+1; // FIFO_DATA read request
    //spi_master_tx_buf[0] = XDATA3*2+1; // current data
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
    // spi_slave needs SPI_MODE3 (adxl355 can use SPI_MODE3 with sclk inverted)
    master.setDataMode(SPI_MODE3); // for DMA, only 1 or 3 is available
    master.setFrequency(8000000); // Hz
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
  float cvx2     = spd > 0 ? 39240.0e3/spd : 0.0;
  uint32_t icvx2 = int(cvx2);
  uint16_t ivx   = spd > 0 ? spd : 0;
  spi_master_tx_buf[0] = 0; // 0: write ram
  spi_master_tx_buf[1] = 0x2; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  spi_master_tx_buf[5] = ivx>>8;
  spi_master_tx_buf[6] = ivx;
  spi_master_tx_buf[7] = icvx2>>24;
  spi_master_tx_buf[8] = icvx2>>16;
  spi_master_tx_buf[9] = icvx2>>8;
  spi_master_tx_buf[10]= icvx2;
  master.transfer(spi_master_tx_buf, 5+4+2); // write speed binary
}

// returns [um/m] sum abs(vz) over 100m/0.25m = 400 points integer
void spi_srvz_read(int32_t *srvz)
{
  spi_master_tx_buf[0] = 1; // 1: read ram
  spi_master_tx_buf[1] = 0x2; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  spi_master_tx_buf[5] = 0; // dummy
  master.transfer(spi_master_tx_buf, spi_master_rx_buf, 6+2*4); // read srvz binary
  srvz[0] = (spi_master_rx_buf[ 6]<<24)|(spi_master_rx_buf[ 7]<<16)|(spi_master_rx_buf[ 8]<<8)|(spi_master_rx_buf[ 9]);
  srvz[1] = (spi_master_rx_buf[10]<<24)|(spi_master_rx_buf[11]<<16)|(spi_master_rx_buf[12]<<8)|(spi_master_rx_buf[13]);
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
  spi_master_tx_buf[0] = 0; // 1: write ram
  spi_master_tx_buf[1] = 0xD; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  rds.ta(0);
  rds.ps("SELFTEST");
  //               1         2         3         4         5         6
  //      1234567890123456789012345678901234567890123456789012345678901234
  rds.rt("abcdefghijklmnopqrstuvwxyz 0123456789 abcdefghijklmnopqrstuvwxyz");
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
  char *name_obd_gps[] = {"OBD", "GPS"};
  char *sensor_status_decode = "XLRY"; // X-no sensors, L-left only, R-right only, Y-both
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
      sprintf(disp_long, "%dMB free %02d:%02d %d km/h WAIT FOR GPS FIX",
        free_MB,
        tm->tm_hour, tm->tm_min,
        speed_kmh);
    }
    else
    {
      if(fast_enough)
        sprintf(disp_short, "%3s   0X", iri2digit);
      else
        sprintf(disp_short, "GO    0X"); // normal
        //sprintf(disp_short, "%3s   0X", iri2digit); // debug
      sprintf(disp_long, "L=%.2f R=%.2f %dMB free %02d:%02d %d km/h RUN=%d",
        iri[0], iri[1],
        free_MB,
        tm->tm_hour, tm->tm_min,
        speed_kmh,
        fast_enough);
    }
    rds.ct(year, tm->tm_mon, tm->tm_mday, tm->tm_hour, tm->tm_min, 0);
  }
  else // NULL pointer
  {
    // null pointer, dummy time
    sprintf(disp_short, "OFF    X");
    sprintf(disp_long,  "SEARCHING FOR %s", name_obd_gps[mode_obd_gps]);
    rds.ct(2000, 0, 1, 0, 0, 0);
  }
  disp_short[5] = free_MB_2n;
  disp_short[6] = name_obd_gps[mode_obd_gps][0];
  disp_short[7] = sensor_status_decode[sensor_check_status];
  rds.ps(disp_short);
  rds.rt(disp_long);
  Serial.println(disp_short);
  Serial.println(disp_long);
  spi_master_tx_buf[0] = 0; // 1: write ram
  spi_master_tx_buf[1] = 0xD; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  master.transfer(spi_master_tx_buf, 5+(4+16+1)*13); // write RDS binary
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
  int checkat[4] = { // make it 12-even
    SPI_READER_BUF_SIZE*1/8 - SPI_READER_BUF_SIZE*1/8%12,
    SPI_READER_BUF_SIZE*2/8 - SPI_READER_BUF_SIZE*2/8%12,
    SPI_READER_BUF_SIZE*3/8 - SPI_READER_BUF_SIZE*3/8%12,
    SPI_READER_BUF_SIZE*4/8 - SPI_READER_BUF_SIZE*4/8%12 - 12,
  }; // list of indexes to check (0 not included)
  int lr[2] = {6, 12}; // l, r index of sensors in rx buf to check
  int16_t v0, v; // sensor signed value
  int i, j;

  for(i = 0; i < 2; i++) // lr index
  {
    v0 = (spi_master_rx_buf[lr[i]+1] << 8)
       | (spi_master_rx_buf[lr[i]  ]  | 1); // remove LSB
    //Serial.print(v0);
    for(j = 0; j < 4; j++) // checkat index
    {
      v = (spi_master_rx_buf[lr[i]+checkat[j]+1] << 8)
        | (spi_master_rx_buf[lr[i]+checkat[j]  ]  | 1); // remove LSB
      //Serial.print("=");
      //Serial.print(v);
      if(v != v0)
        retval |= 1<<i;
    }
    //Serial.print(", ");
  }
  //Serial.println("");
  return retval;
}

void open_log_wav(struct tm *tm)
{
  #if 1
  sprintf(filename_data, "/profilog/data/%04d%02d%02d-%02d%02d.wav",
    tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
  #else
  sprintf(filename_data, "/profilog/data/%04d%02d%02d.wav",
    tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday);
  #endif
  #if 1
  //SD_MMC.remove(filename_data);
  file_accel = SD_MMC.open(filename_data, FILE_APPEND);
  // check appending file position (SEEK_CUR) and if 0 then write header
  if(file_accel.position() == 0)
    write_wav_header();
  #else
  SD_MMC.remove(filename_data);
  SD_MMC.remove("/profilog/data/accel.wav");
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
    //Serial.println(sensor_check_status);
  }
}

void write_stop_delimiter_wav()
{
  const uint8_t stop_delimiter[12] = // should result in char '#' (ascii 35)
  {
    1, 0, //  1
    1, 0, //  2
    0, 0, //  4
    0, 0, //  8
    0, 0, // 16
    1, 0, // 32
  };
  if(logs_are_open)
    file_accel.write(stop_delimiter, sizeof(stop_delimiter));
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
  String last_nmea_line = file_lastnmea.readStringUntil('\n');
  strcpy(lastnmea, last_nmea_line.c_str());
  Serial.print("read last nmea: ");
  Serial.println(lastnmea);
  file_lastnmea.close();
  if(check_nmea_crc(lastnmea))
  {
    if (nmea2tm(lastnmea, &tm))
      set_date_from_tm(&tm);
    nmea2latlon(lastnmea, &last_latlon); // parsing also invalidates lastnmea content
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

void write_tag(char *a)
{
  int i;
  spi_master_tx_buf[0] = 0; // 1: write ram
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
    spi_master_tx_buf[0] = 0; // 1: write ram
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
  spi_master_tx_buf[0] = 0; // 1: write ram
  spi_master_tx_buf[1] = 5; // addr [31:24] msb
  spi_master_tx_buf[2] = 0; // addr [23:16]
  spi_master_tx_buf[3] = 0; // addr [15: 8]
  spi_master_tx_buf[4] = 0; // addr [ 7: 0] lsb
  for(i = 0; i < n; i++)
    spi_master_tx_buf[i+5] = ((i+8)&15)<<4; // create wav
  master.transfer(spi_master_tx_buf, n+5); // write pcm to play
}

// write n bytes to 52-byte RDS memory
void write_rds(uint8_t *a, int n)
{
  int i;
  spi_master_tx_buf[0] = 0; // 1: write ram
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
  uint8_t subchunk2size_bytes[4] = {subchunk2size, subchunk2size>>8, subchunk2size>>16, subchunk2size>>24};
  uint32_t chunksize = pos - 8;
  uint8_t chunksize_bytes[4] = {chunksize, chunksize>>8, chunksize>>16, chunksize>>24};
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

void write_kml_header(void)
{
  //kml_header();
  //file_kml.write((uint8_t *)kmlbuf, str_kml_header_len);
  file_kml.write('H');
}

// finalize kml file, no more writes after this
void write_kml_footer(void)
{
  //kml_footer("2021-07-24T11:54:19.0Z", "2021-07-24T11:54:19.0Z"); // generate kml footer in kmlbuf
  //file_kml.write((uint8_t *)kmlbuf, str_kml_footer_len);
  file_kml.write('F');
}

void open_log_kml(struct tm *tm)
{
  #if 1
  sprintf(filename_data, "/profilog/data/%04d%02d%02d-%02d%02d.kml",
    tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min);
  #else
  sprintf(filename_data, "/profilog/data/%04d%02d%02d.kml",
    tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday);
  #endif
  file_kml = SD_MMC.open(filename_data, FILE_APPEND);
  // check appending file position (SEEK_CUR) and if 0 then write header
  if(file_kml.position() == 0)
    write_kml_header();
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
  spi_master_tx_buf[0] = DEVID_AD*2+1; // read ID (4 bytes expected)
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

void read_cfg(void)
{
  file_cfg = SD_MMC.open("/profilog/config/profilog.cfg", FILE_READ);
  int linecount = 0;
  Serial.println("*** open /profilog/config/profilog.cfg ***");
  while(file_cfg.available())
  {
    String cfgline = file_cfg.readStringUntil('\n');
    if(cfgline.length() < 2) // skip empty and short lines
      continue;
    if(cfgline[0] == '#') // skip comments
      continue;
    int delimpos = cfgline.indexOf(':'); // delimiter position
    if(delimpos < 2) // skip lines without proper ":" delimiter
      continue;
    linecount++;
    String varname = cfgline.substring(0, delimpos-1);
    varname.trim(); // inplace trim leading and trailing whitespace
    String varvalue = cfgline.substring(delimpos+1); // to end of line
    varvalue.trim(); // inplace trim leading and trailing whitespace
    if     (varname.equalsIgnoreCase("ap_name" )) AP_NAME  = varvalue;
    else if(varname.equalsIgnoreCase("ap_pass" )) AP_PASS  = varvalue;
    else if(varname.equalsIgnoreCase("dns_host")) DNS_HOST = varvalue;
    else if(varname.equalsIgnoreCase("gps_name")) GPS_NAME = varvalue;
    else if(varname.equalsIgnoreCase("gps_mac" )) parse_mac(GPS_MAC, varvalue);
    else if(varname.equalsIgnoreCase("gps_pin" )) GPS_PIN  = varvalue;
    else if(varname.equalsIgnoreCase("obd_name")) OBD_NAME = varvalue;
    else if(varname.equalsIgnoreCase("obd_mac" )) parse_mac(OBD_MAC, varvalue);
    else if(varname.equalsIgnoreCase("obd_pin" )) OBD_PIN  = varvalue;
    else
    {
      Serial.print("/profilog/config/profilog.cfg: error in line ");
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
  Serial.print("AP_NAME  : "); Serial.println(AP_NAME);
  Serial.print("AP_PASS  : "); Serial.println(AP_PASS);
  Serial.print("DNS_HOST : "); Serial.println(DNS_HOST);
  Serial.println("*** close /profilog/config/profilog.cfg ***");
  file_cfg.close();
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
}

void write_stop_delimiter()
{
  if(logs_are_open == 0)
    return;
  if(log_wav_kml&1)
    write_stop_delimiter_wav();
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
