#include "pins.h"
#include <sys/time.h>

#include "BluetoothSerial.h"
// set Board->ESP32 Arduino->ESP32 Dev Module

// PPS and IRQ connected with wire
#include "soc/mcpwm_reg.h"
#include "soc/mcpwm_struct.h"
#include "driver/mcpwm.h"
// SD card 4-bit mode
#include "sdcard.h"
// NMEA simple parsing for $GPRMC NMEA sentence
#include "nmea.h"

BluetoothSerial SerialBT;

// TODO: read address from SD card gps.mac
//uint8_t address[6] = {0x10, 0xC6, 0xFC, 0x84, 0x35, 0x2E};
// String name = "Garmin GLO #4352e"; // new

uint8_t address[6] = {0x10, 0xC6, 0xFC, 0x14, 0x6B, 0xD0};
// String name = "Garmin GLO #46bd0"; // old from rpi box

char *pin = "1234"; //<- standard pin would be provided by default

bool connected = false;
char *speakfile = NULL;

// int64_t esp_timer_get_time() returns system microseconds
int64_t IRAM_ATTR us()
{
  return esp_timer_get_time();
}

// better millis
uint32_t IRAM_ATTR ms()
{
  return (uint32_t) (esp_timer_get_time() / 1000LL);
}

// read raw 32-bit CPU ticks, running at 240 MHz, wraparound 18s
inline uint32_t IRAM_ATTR cputix()
{
  uint32_t ccount;
  asm volatile ( "rsr %0, ccount" : "=a" (ccount) );
  return ccount;
}

// cputix related
#define M 1000000
#define G 1000000000
#define ctMHz 240
#define PPSHz 10
// nominal period for PPSHz
#define Period1Hz 63999
// constants to help PLL
const int16_t phase_target = 0;
const int16_t period = 1000 / PPSHz;
const int16_t halfperiod = period / 2;

// rotated log of 256 NMEA timestamps and their cputix timestamps
uint8_t inmealog = 0;
int32_t nmea2ms_log[256]; // difference nmea-ms() log
int64_t nmea2ms_sum;
int32_t nmea2ms_dif;

// this ISR is software PLL that will lock to GPS signal
// by adjusting frequency of MCPWM signal to match
// time occurence of the ISR with averge difference between
// GPS clock and internal ESP32 clock.
// average difference is calculated at NMEA reception in loop()

// connect MCPWM PPS pin output to some input pin for interrupt
// workaround to create interrupt at each MCPWM cycle because
// MCPWM doesn't or I don't know how to generate software interrupt.
// the ISR will sample GPS tracking timer and calculate
// MCPWM period correction to make a PLL that precisely locks to
// GPS, it does the PPS signal recovery
static void IRAM_ATTR isr_handler()
{
  uint32_t ct = cputix(); // hi-resolution timer 18s wraparound
  static uint32_t ctprev;
  uint32_t t = ms();
  static uint32_t tprev;
  int32_t ctdelta2 = (ct - ctprev) / ctMHz; // us time between irq's
  ctprev = ct;
  int16_t phase = (nmea2ms_dif + t) % period;
  int16_t period_correction = (phase_target - phase + 2 * period + halfperiod) % period - halfperiod;
  //if(period_correction < -30 || period_correction > 30)
  //  period_correction /= 2; // fast convergence
  //else
  period_correction /= 4; // slow convergence and hysteresis around 0
  if (period_correction > 1530) // upper limit to prevent 16-bit wraparound
    period_correction = 1530;
  MCPWM0.timer[0].period.period = Period1Hz + period_correction;
#if 0
  // debug PPS sync
  Serial.print(nmea2ms_dif, DEC); // average nmea time - ms() time
  Serial.print(" ");
  Serial.print(ctdelta2, DEC); // microseconds between each irq measured by CPU timer
  Serial.print(" ");
  Serial.print(phase, DEC); // less:PPS early, more:PPS late
  //Serial.print(" ");
  //Serial.print((uint32_t)us(), DEC);
  Serial.println(" irq");
#endif
}

/* test 64-bit functions */
#if 0
void test64()
{
  uint64_t G = 1000000000; // 1e9 giga
  uint64_t x = 72 * G; // 72e9
  uint64_t r = x + 1234;
  uint32_t y = x / G;
  uint32_t z = r % G;
  Serial.println(z, DEC);
}
#endif

// fill sum and log with given difference d
void init_nmea2ms(int32_t d)
{
  // initialize nmea to ms() statistics sum
  nmea2ms_sum = d * 256;
  for (int i = 0; i < 256; i++)
    nmea2ms_log[i] = d;
}

void setup() {
  Serial.begin(115200);
  //set_system_time(1527469964);
  //set_date_time(2021,4,1,12,30,45);
  //pinMode(PIN_BTN, INPUT);
  //attachInterrupt(PIN_BTN, isr_handler, FALLING);
  pinMode(PIN_IRQ, INPUT);
  attachInterrupt(PIN_IRQ, isr_handler, RISING);
  SerialBT.begin("ESP32", true);
  SerialBT.setPin(pin);
  Serial.println("Bluetooth master started");

  mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM0A, PIN_PPS); // Initialise channel MCPWM0A on PPS pin
  MCPWM0.clk_cfg.prescale = 24;                 // Set the 160MHz clock prescaler to 24 (160MHz/(24+1)=6.4MHz)
  MCPWM0.timer[0].period.prescale = 100 / PPSHz - 1; // Set timer 0 prescaler to 9 (6.4MHz/(9+1))=640kHz)
  MCPWM0.timer[0].period.period = 63999;        // Set the PWM period to 10Hz (640kHz/(63999+1)=10Hz)
  MCPWM0.channel[0].cmpr_value[0].val = 6400;   // Set the counter compare for 10% duty-cycle
  MCPWM0.channel[0].generator[0].utez = 2;      // Set the PWM0A ouput to go high at the start of the timer period
  MCPWM0.channel[0].generator[0].utea = 1;      // Clear on compare match
  MCPWM0.timer[0].mode.mode = 1;                // Set timer 0 to increment
  MCPWM0.timer[0].mode.start = 2;               // Set timer 0 to free-run
  init_nmea2ms(0);

  spi_init();
  rds_init();
  for (int i = 0; i < 5; i++)
  {
    adxl355_init();
    delay(500);
  }
#if 0
  // RDS test: fill some memory data
  uint8_t rdsmsg[13] = {0xca, 0xfe, 0xa0, 0x01, 0x00, 0x2e, 0x8e, 0x1c, 0xc2, 0x31, 0x51, 0x15, 0xfb};
  //uint8_t rdsmsg[13] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
  write_rds(rdsmsg, sizeof(rdsmsg));
#endif
  spi_rds_write();
}

void reconnect()
{
  // connect(address) is fast (upto 10 secs max), connect(name) is slow (upto 30 secs max) as it needs
  // to resolve name to address first, but it allows to connect to different devices with the same name.
  // Set CoreDebugLevel to Info to view devices bluetooth address and device names

  //connected = SerialBT.connect(name); // slow
  connected = SerialBT.connect(address); // fast

  // return value "connected" doesn't mean much
  // it is sometimes true even if not connected.
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

#if 0
void set_date_time(int year, int month, int day, int h, int m, int s)
{
  time_t t_of_day;
  struct tm t;

  t.tm_year = year - 1900; // year since 1900
  t.tm_mon  = month - 1;  // Month, 0 - jan
  t.tm_mday = day;        // Day of the month
  t.tm_hour = h;
  t.tm_min  = m;
  t.tm_sec  = s;
  t_of_day  = mktime(&t);
  set_system_time(t_of_day);
}
#endif

// parse NMEA ascii string -> write to struct tm
int nmea2tm(char *a, struct tm *t)
{
  char *b = nthchar(a, 9, ',');
  if (b == NULL)
    return 0;
  t->tm_year  = (b[ 5] - '0') * 10 + (b[ 6] - '0') + 100;
  t->tm_mon   = (b[ 3] - '0') * 10 + (b[ 4] - '0') - 1;
  t->tm_mday  = (b[ 1] - '0') * 10 + (b[ 2] - '0');
  t->tm_hour  = (a[ 7] - '0') * 10 + (a[ 8] - '0');
  t->tm_min   = (a[ 9] - '0') * 10 + (a[10] - '0');
  t->tm_sec   = (a[11] - '0') * 10 + (a[12] - '0');
  return 1;
}

// parse NMEA ascii string -> return mph x100 speed (negative -1 if no fix)
int nmea2spd(char *a)
{
  //char *b = a+46; // simplified locating 7th ","
  char *b = nthchar(a, 7, ',');
  // simplified parsing, string has form ,000.00,
  if (b[4] != '.' || b[7] != ',')
    return -1;
  return (b[1] - '0') * 10000 + (b[2] - '0') * 1000 + (b[3] - '0') * 100 + (b[5] - '0') * 10 + (b[6] - '0');
}

static uint8_t datetime_is_set = 0;
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
  sprintf(pr, "datetime %04d-%02d-%02d %02d:%02d:%02d", year, month, day, h, m, s);
  Serial.println(pr);
#endif
}

#if 0
// debug tagger: constant test string
char tag_test[256] = "$ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789*00\n";
#endif

void loop()
{
  static uint32_t tprev;
  uint32_t t = ms();
  static char nmea[128];
  static char c;
  static int i = 0;
  uint32_t tdelta = t - tprev;
  static uint32_t ct0; // first char in line millis timestamp
  static uint32_t tprev_wav, tprev_wavp;
  uint32_t tdelta_wav, tdelta_wavp;
  static uint32_t tspeak_ready;
  static struct tm tm;

#if 1
  if (connected && SerialBT.available() > 0)
  {
    c = 0;
#if 1
    while (SerialBT.available() > 0 && c != '\n')
    {
      if (i == 0)
        ct0 = ms();
      // read returns char or -1 if unavailable
      c = SerialBT.read();
      if (i < sizeof(nmea) - 3)
        nmea[i++] = c;
    }
#endif
    if (i > 5 && c == '\n') // line complete
    {
      //if(nmea[1]=='P' && nmea[3]=='R') // print only $PGRMT, we need Version 3.00
      if ((i > 50 && i < 90) // accept lines of expected length
          && (nmea[1] == 'G' // accept 1st letter is G
              && (nmea[4] == 'M' /*|| nmea[4]=='G'*/))) // accept 4th letter is M or G, accept $GPRMC and $GPGGA
        if (check_nmea_crc(nmea)) // filter out NMEA sentences with bad CRC
        {
          nmea[i] = 0;
          // there's bandwidth for only one NMEA sentence at 10Hz (not two sentences)
          // time calculation here should receive no more than one NMEA sentence for one timestamp
          write_tag(nmea);
#if 0
          // debug tagger with constant test string
          if (nmea[4] == 'M')
            write_tag(tag_test);
#endif
#if 0
          // debug NMEA data
          Serial.print(nmea);
#endif
          knots = nmea2spd(nmea); // parse speed
          // hysteresis for logging
          // 100 knots = 1 kt = 0.514444 m/s = 1.852 km/h
          if (knots > 550)
          {
            if (fast_enough == 0)
            {
              Serial.print(knots * 1852 / 100000);
              Serial.println(">10 km/h fast enough - start logging");
            }
            fast_enough = 1;
          }
          if (knots < 220)
          {
            if (fast_enough)
            {
              Serial.print(knots * 1852 / 100000);
              Serial.println("<4 km/h not fast enough - stop logging");
            }
            fast_enough = 0;
          }
          int daytime = nmea2s(nmea + 7);
          int32_t nmea2ms = daytime * 100 - ct0; // difference from nmea to timer
          if (nmea2ms_sum == 0) // sum is 0 only at reboot
            init_nmea2ms(nmea2ms); // speeds up convergence
          nmea2ms_sum += nmea2ms - nmea2ms_log[inmealog]; // moving sum
          nmea2ms_dif = nmea2ms_sum / 256;
          nmea2ms_log[inmealog++] = nmea2ms;
          write_logs(); // use SPI_MODE1
          //Serial.println(daytime, DEC);
          //Serial.println(ct0, HEX);
          // isolate date
#if 0
          char *date_begin = nthchar(nmea, 9, ',');
          char *date_end = nthchar(nmea, 10, ',');
          date_end[0] = 0;
          Serial.println(date_begin);
#endif
          if (nmea2tm(nmea, &tm))
          {
            static uint8_t prev_min;
            set_date_from_tm(&tm);
            pinMode(PIN_LED, OUTPUT);
            digitalWrite(PIN_LED, LED_ON);
            mount();
            open_logs(&tm);
            if (tm.tm_min != prev_min)
            { // every minute
              // update RDS time and speed
              rds_message(&tm);
#if 0
              Serial.print(tm.tm_hour);
              Serial.print(":");
              Serial.print(tm.tm_min);
              Serial.print(" ");
              Serial.print(knots);
              Serial.println(" kt*100");
#endif
              if (!pcm_is_open)
              {
                if (knots < 0)
                  speakfile = "/speak/wait.wav";
                else
                {
                  if (fast_enough)
                    speakfile = "/speak/record.wav";
                  else
                    speakfile = "/speak/ready.wav";
                }
              }
              prev_min = tm.tm_min;
            }
          }
        }
      tprev = t;
      i = 0;
    }
  }
  else
  {
    // check for serial line silence to determine if
    // GPS needs to be reconnected
    // reported 15s silence is possible http://4river.a.la9.jp/gps/report/GLO.htm
    // for practical debugging we wait for less here
    if (tdelta > 10000) // 10 seconds of serial silence? then reconnect
    {
      pinMode(PIN_LED, INPUT);
      digitalWrite(PIN_LED, LED_OFF);
      close_logs();
      ls();
      umount();
      rds_message(NULL);
      reconnect();
      datetime_is_set = 0; // set datetime again
      tprev = ms();
      i = 0;
    }
    else
      write_logs();
  }
#endif

  if (!pcm_is_open) // NULL: we are ready to speak new file,
  {
    tdelta_wav = t - tprev_wav;
    if (tdelta_wav > 7000 && tdelta > 1000 && tdelta < 4000 && are_logs_open() == 0)
      speakfile = "/speak/search.wav";
  }
#if 0
  if (speakfile == NULL && pcm_is_open == 0 && (((int32_t)t) - (int32_t)tspeak_ready) > 0) // NULL: we are ready to speak new file,
  {
    // PCM is now ready for next file
    speakfile = "/speak/1.wav";
  }
#endif
  if (speakfile != NULL && pcm_is_open == 0)
  {
    // start speech
    mount();
    open_pcm(speakfile); // load buffer with start of the file
    tprev_wavp = ms(); // reset play timer from now, after start of PCM file
    tprev_wav = t; // prevent too often starting of the speech
  }
  else
  {
    // continue speaking from remaining parts of the file
    // refill wav-play buffer
    tdelta_wavp = t - tprev_wavp; // how many ms have passed since last refill
    if (tdelta_wavp > 200 && pcm_is_open) // 200 ms is about 2.2KB to refill
    {
      int remaining_bytes;
      remaining_bytes = play_pcm(tdelta_wavp * 11); // approx 11 samples per ms at 11025 rate
      tprev_wavp = t;
      if (!pcm_is_open)
      {
        tspeak_ready = t + remaining_bytes / 11 + 359; // estimate when PCM will be ready
        speakfile = NULL; // consumed
      }
    }
  }
#if 0
  // print adxl data
  spi_slave_test(); // use SPI_MODE3
  //spi_direct_test(); // use SPI_MODE3 if sclk inverted, otherwise SPI_MODE1
  delay(100);
#endif
}
