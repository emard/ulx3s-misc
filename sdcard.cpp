#include "pins.h"
#include "sdcard.h"
#include "adxl355.h"
// Manage Libraries -> ESP32DMASPI
#include <ESP32DMASPIMaster.h> // Version 0.1.0 tested

ESP32DMASPI::Master master;
uint8_t* spi_master_tx_buf;
uint8_t* spi_master_rx_buf;
static const uint32_t BUFFER_SIZE = 1024;

File file_gps, file_accel;
int logs_are_open = 0;

void adxl355_write_reg(uint8_t a, uint8_t v)
{
  spi_master_tx_buf[0] = a*2; // write range
  spi_master_tx_buf[1] = v;
  //digitalWrite(PIN_CSN, 0);
  master.transfer(spi_master_tx_buf, spi_master_rx_buf, 2);
  //digitalWrite(PIN_CSN, 1);
}

void adxl355_init(void)
{
  //Serial.println("initializing ADXL");
  //delay(100);
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
  //delay(100);
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

    master.setDataMode(SPI_MODE1); // for DMA, only 1 or 3 is available
    // master.setFrequency(SPI_MASTER_FREQ_8M); // too fast for bread board...
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


void listDir(fs::FS &fs, const char * dirname, uint8_t levels){
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

  logs_are_open = 0;
}

void ls(void)
{
  listDir(SD_MMC, "/", 0);
}

void open_logs(void)
{
  if(logs_are_open != 0)
    return;
  #if 0
  file_gps   = SD_MMC.open("/gps.log",   FILE_APPEND);
  file_accel = SD_MMC.open("/accel.log", FILE_APPEND);
  #else
  //SD_MMC.remove("/test.txt");
  //SD_MMC.remove("/foo.txt");
  file_gps   = SD_MMC.open("/gps.log",   FILE_WRITE);
  file_accel = SD_MMC.open("/accel.log", FILE_WRITE);
  #endif
  logs_are_open = 1;
}

void write_logs(void)
{
  static uint8_t gps[64];
  if(logs_are_open == 0)
    return;
  #if 0
  // reading ID and printing
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
  #endif
  #if 1
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
  #endif
}

void close_logs(void)
{
  if(logs_are_open == 0)
    return;
  file_gps.close();
  file_accel.close();
  logs_are_open = 0;
}
