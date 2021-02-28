#include "sdcard.h"
File file_gps, file_accel;
int logs_are_open = 0;

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
  file_gps   = SD_MMC.open("/gps.log",   FILE_WRITE);
  file_accel = SD_MMC.open("/accel.log", FILE_WRITE);
  #endif
  logs_are_open = 1;
}

void write_logs(void)
{
  static uint8_t accel[900]; // 100 samples of 9-bytes
  static uint8_t gps[64];
  if(logs_are_open == 0)
    return;
  file_gps.write(gps, sizeof(gps));
  file_accel.write(accel, sizeof(accel));
}

void close_logs(void)
{
  if(logs_are_open == 0)
    return;
  file_gps.close();
  file_accel.close();
  logs_are_open = 0;
}
