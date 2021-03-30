#include <stdio.h>
#include <stdint.h>

void createwav6ch(void)
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
  
  FILE *f = fopen("accel.wav", "r+b");
  fwrite(wavhdr, sizeof(wavhdr), 1, f);
  
  uint8_t sample[12];
  for(int i = 0; i < 1024; i++)
  {
    for(int j = 0; j < 12; j++)
      sample[j] = i;
    fwrite(sample, sizeof(sample), 1, f);    
  }  
  fclose(f);  
}

void createwav2ch(void)
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
    0x02, 0x00, // num channels = 2
    0x00, 0x04, 0x00, 0x00, // sample rate = 1024 Hz
    0x00, 0x08, 0x00, 0x00, // byte rate = 2*1024 = 2048
    0x04, 0x00, // block align = 4 bytes
    0x10, 0x00, // bits per sample = 16 bits
    // subchunk2: data    
    'd', 'a', 't', 'a',
    0x00, 0x00, 0x00, 0x00, // chunk size bytes (len), file growing, not yet known       
  };
  
  FILE *f = fopen("accel.wav", "w+b");
  fwrite(wavhdr, sizeof(wavhdr), 1, f);

  uint8_t sample[4];
  for(int i = 0; i < 512; i++)
  {
    for(int j = 0; j < sizeof(sample); j++)
      sample[j] = i;
    fwrite(sample, sizeof(sample), 1, f);    
  }  
  fclose(f);  
}

void fixwav(void)
{
  //uint8_t len_bytes[4] = {1, 2, 3, 4};
  puts("fixing wav");
  FILE *f = fopen("accel.wav", "r+b");
  fseek(f, 0, SEEK_END);
  uint32_t total_len = ftell(f);
  printf("total %d\n", total_len);

  fseek(f, 4, SEEK_SET);
  printf("writing at %d\n", ftell(f));
  uint32_t len1 = total_len - 8;
  uint8_t len1_bytes[4] = {len1, len1>>8, len1>>16, len1>>24};
  fwrite(len1_bytes, 4, 1, f);

  fseek(f, 40, SEEK_SET);
  printf("writing at %d\n", ftell(f));
  uint32_t len2 = total_len - 44;
  uint8_t len2_bytes[4] = {len2, len2>>8, len2>>16, len2>>24};
  fwrite(len2_bytes, 4, 1, f);

  fclose(f);
}

int main(int argc, char *argv[])
{
  //createwav6ch();
  fixwav();
  return 0;
}
