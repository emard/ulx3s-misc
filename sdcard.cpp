#include "pins.h"
#include "sdcard.h"
#include "adxl355.h"

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

File file_gps, file_accel, file_pcm;
int card_is_mounted = 0;
int logs_are_open = 0;
int pcm_is_open = 0;
int sensor_check_status = 0;
int knots = -1; // knots*100
int fast_enough = 0; // for speed logging hysteresis

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

void rds_ct_tm(struct tm *tm)
{
  char disp_short[9], disp_long[65];
  if(tm)
  {
    uint16_t year = tm->tm_year + 1900;
    if(knots < 0)
    {
      sprintf(disp_short, "WAIT  LR");
      sprintf(disp_long, "%02d:%02d WAIT FOR GPS FIX", tm->tm_hour, tm->tm_min);
    }
    else
    {
      if(fast_enough)
        sprintf(disp_short, "RUN   LR");
      else
        sprintf(disp_short, "GO    LR");
      sprintf(disp_long, "%02d:%02d %d.%02d kt RUN=%d", tm->tm_hour, tm->tm_min, knots/100, knots%100, fast_enough);
    }
    rds.ct(year, tm->tm_mon, tm->tm_mday, tm->tm_hour, tm->tm_min, 0);
  }
  else // NULL pointer
  {
    // null pointer, dummy time
    sprintf(disp_short, "OFF   LR");
    sprintf(disp_long,  "SEARCHING FOR GPS");
    rds.ct(2000, 0, 1, 0, 0, 0);
  }
  disp_short[6] = sensor_check_status & 1 ? 'L' : ' ';
  disp_short[7] = sensor_check_status & 2 ? 'R' : ' ';
  rds.ps(disp_short);
  rds.rt(disp_long);
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

void open_logs(void)
{
  if(logs_are_open != 0)
    return;
  #if 1
  SD_MMC.remove("/accel.wav");
  //file_gps   = SD_MMC.open("/gps.log",   FILE_APPEND);
  file_accel = SD_MMC.open("/accel.wav", FILE_APPEND);
  // check appending file position (SEEK_CUR) and if 0 then write header
  if(file_accel.position() == 0)
    write_wav_header();
  #else
  //SD_MMC.remove("/test.txt");
  //SD_MMC.remove("/foo.txt");
  //SD_MMC.remove("/accel.log");
  //file_gps   = SD_MMC.open("/gps.log",   FILE_WRITE);
  file_accel = SD_MMC.open("/accel.wav", FILE_WRITE);
  write_wav_header();
  #endif
  Serial.print("file position (expect 44) ");
  Serial.println(file_accel.position(), DEC);
  logs_are_open = 1;
}

#if 0
// using ADXL 32-sample buffer is too small, overruns
void write_logs_old1(void)
{
  static uint8_t gps[64];
  if(logs_are_open == 0)
    return;
  #if 1
  // begin read fifo and write to SD
  if(adxl355_available()<8)
    return;
  uint8_t n = adxl355_rdfifo16();
  //file_gps.write(gps, sizeof(gps));
  //if(n == 0)
  //  return;
  file_accel.write(spi_master_tx_buf, n*2);
  if(n < 32)
    return;
  Serial.print("overrun");
  //Serial.print(n);
  #if 0
  for(int i = 0; i < 6; i++)
  {
    Serial.print(" ");
    Serial.print(spi_master_tx_buf[i], HEX);
  }
  #endif
  Serial.println("");
  // end read fifo and write to SD
  #endif
}
#endif

#if 0
// too complex code
// write to SD when more than BUF_DATA_WRITE bytes are collected
#define BUF_DATA_WRITE 2000
void write_logs(void)
{
  static uint16_t prev_ptr = 0;
  uint16_t ptr, dif;

  ptr = (SPI_READER_BUF_SIZE + spi_slave_ptr() - 2) % SPI_READER_BUF_SIZE; // written content is 2 bytes behind pointer
  ptr -= ptr % 12; // trim to even number of samples (12 bytes is one full sample)
  dif = (SPI_READER_BUF_SIZE + ptr - prev_ptr) % SPI_READER_BUF_SIZE;
  if(dif > BUF_DATA_WRITE)
  {
    if(logs_are_open)
    {
      if(ptr > prev_ptr)
      {
        // 1-part read
        spi_slave_read(prev_ptr, dif);
        file_accel.write(spi_master_rx_buf+6, dif);
        Serial.print("1");
      }
      else
      {
        uint16_t part1len = SPI_READER_BUF_SIZE - prev_ptr;
        uint16_t part2len = dif - part1len;
        // 2-part read
        spi_slave_read(prev_ptr, part1len);
        file_accel.write(spi_master_rx_buf+6, part1len);
        spi_slave_read(0, part2len);
        file_accel.write(spi_master_rx_buf+6, part2len);
        Serial.print("2");
      }
      Serial.print(" part ptr ");
      Serial.print(ptr, DEC);
      Serial.print(" write buf size ");
      Serial.println(dif, DEC);
    }
    prev_ptr = ptr;
  }
}
#endif

#if 1
void write_logs(void)
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
#endif


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

void close_logs(void)
{
  if(logs_are_open == 0)
    return;
  logs_are_open = 0;
  //file_gps.close();
  //finalize_wav_header();
  file_accel.close();
}

int are_logs_open()
{
  return logs_are_open;
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
