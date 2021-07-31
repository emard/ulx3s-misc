#include "pins.h"
#include "web.h"
#include "kml.h"
#include <sys/time.h>
#include <WiFi.h> // to speak IP

#include "BluetoothSerial.h"
// set Board->ESP32 Arduino->ESP32 Dev Module
// CPU Frequency: 240 MHz
// Partition Scheme: No OTA (2MB APP/2MB SPIFFS)

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
//uint8_t GPS_MAC[6] = {0x10, 0xC6, 0xFC, 0x84, 0x35, 0x2E};
// String GPS_NAME = "Garmin GLO #4352e"; // new

//uint8_t GPS_MAC[6] = {0x10, 0xC6, 0xFC, 0x14, 0x6B, 0xD0};
// String GPS_NAME = "Garmin GLO #46bd0"; // old from rpi box

// char *GPS_PIN = "1234"; //<- standard pin would be provided by default

bool connected = false;
char *speakfile = NULL;
char *nospeak[] = {NULL};
char **speakfiles = nospeak;

// optional loop handler functions
void loop_run(void), loop_web(void);
void (*loop_pointer)() = &loop_run;

static char *digit_file[] =
{
  "/profilog/speak/0.wav",
  "/profilog/speak/1.wav",
  "/profilog/speak/2.wav",
  "/profilog/speak/3.wav",
  "/profilog/speak/4.wav",
  "/profilog/speak/5.wav",
  "/profilog/speak/6.wav",
  "/profilog/speak/7.wav",
  "/profilog/speak/8.wav",
  "/profilog/speak/9.wav",
  NULL
};
static char *speak2digits[] = {digit_file[0], digit_file[0], NULL, NULL};
static char *sensor_status_file[] =
{
  "/profilog/speak/nsensor.wav",
  "/profilog/speak/nright.wav",
  "/profilog/speak/nleft.wav",
  NULL
};
static char *speakaction[] = {"/profilog/speak/search.wav", NULL, NULL};

static char *sensor_balance_file[] =
{
  NULL, // ok
  "/profilog/speak/lstrong.wav",
  "/profilog/speak/rstrong.wav",
};

static char *speakip[16] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, };

uint32_t t_ms; // t = ms();
uint32_t ct0; // first char in line millis timestamp
uint32_t ct0_prev; // for travel calculation
char line[256]; // incoming line of data from bluetooth GPS/OBD
int line_i = 0; // line index
char line_terminator = '\n'; // '\n' for GPS, '\r' for OBD
uint32_t line_tprev; // to determine time of latest incoming complete line
uint32_t line_tdelta; // time between prev and now
int travel_mm = 0; // travelled mm (v*dt)
int travel100m, travel100m_prev = 0; // previous 100m travel
int session_log = 0; // request new timestamp filename when reconnected
int speak_search = 1; // 0 - don't search, 1-search gps, 2-search obd
int32_t srvz[2];
//int iri_balance = 0;
int stopcount = 0;

// form nmea and travel in GPS mode
int daytime = 0;
int daytime_prev = 0; // seconds x10 (0.1s resolution) for dt

char prompt_obd = '>'; // after promot send obd_request_kmh
char *obd_request_kmh = "010D\r";
uint8_t obd_retry = 3; // bit pattern for OBD retry in case of silence

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

  spi_init();
  rds_init();
  spi_rds_write();

  int web = ((~spi_btn_read()) & 1); // hold BTN0 and plug power to enable web server
  if(web)
  {
    loop_pointer = &loop_web;
    mount();
    read_cfg();
    finalize_data(&tm);
    read_last_nmea();
    web_setup();
    speakaction[0] = "/profilog/speak/webserver.wav"; // TODO say web server maybe IP too
    speakaction[1] = NULL;
    speakfiles = speakaction;
    return;
  }

  for (int i = 0; i < 6; i++)
  {
    delay(100);
    adxl355_init();
  }

  mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM0A, PIN_PPS); // Initialise channel MCPWM0A on PPS pin
  MCPWM0.clk_cfg.prescale = 24;                 // Set the 160MHz clock prescaler to 24 (160MHz/(24+1)=6.4MHz)
  MCPWM0.timer[0].period.prescale = 100 / PPSHz - 1; // Set timer 0 prescaler to 9 (6.4MHz/(9+1))=640kHz)
  MCPWM0.timer[0].period.period = 63999;        // Set the PWM period to 10Hz (640kHz/(63999+1)=10Hz)
  MCPWM0.channel[0].cmpr_value[0].val = 6400;   // Set the counter compare for 10% duty-cycle
  MCPWM0.channel[0].generator[0].utez = 2;      // Set the PWM0A ouput to go high at the start of the timer period
  MCPWM0.channel[0].generator[0].utea = 1;      // Clear on compare match
  MCPWM0.timer[0].mode.mode = 1;                // Set timer 0 to increment
  MCPWM0.timer[0].mode.start = 2;               // Set timer 0 to free-run

  t_ms = ms();
  line_tprev = t_ms-5000;
  // line_tprev sets 5s silence in the past. reconnect comes at 10s silance.
  // speech starts at 7s silence. Before speech, 2s must be allowed
  // for sensors to start reading data, otherwise it will false report
  // "no sensors".

  kml_init(); // sets globals using strlen/strstr

  #if 0 // old code
  int obd = ((spi_btn_read()) & 2); // hold BTN1 and plug power to run OBD2 demo
  if(obd)
  {
    loop_pointer = &loop_obd;
    mount();
    read_cfg();
    SerialBT.begin("ESP32", true);
    SerialBT.setPin(OBD_PIN.c_str());
    speakaction[0] = "/profilog/speak/searchobd.wav"; // TODO say OBD
    speakaction[1] = NULL;
    speakfiles = speakaction;
    Serial.println("OBD demo");
    return;
  }
  #endif

  pinMode(PIN_IRQ, INPUT);
  attachInterrupt(PIN_IRQ, isr_handler, RISING);

  init_nmea2ms(0);

  mount();
  read_cfg();
  read_last_nmea();
  umount();

  SerialBT.begin("ESP32", true);
  SerialBT.setPin(GPS_PIN.c_str());
  Serial.println("Bluetooth master started");

  spi_speed_write(0); // normal
}

void reconnect()
{
  // connect(address) is fast (upto 10 secs max), connect(name) is slow (upto 30 secs max) as it needs
  // to resolve name to address first, but it allows to connect to different devices with the same name.
  // Set CoreDebugLevel to Info to view devices bluetooth address and device names

  //connected = SerialBT.connect(name); // slow with String name
  connected = SerialBT.connect(GPS_MAC); // fast with uint8_t GPS_MAC[6]

  // return value "connected" doesn't mean much
  // it is sometimes true even if not connected.
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


#if 0
// debug tagger: constant test string
char tag_test[256] = "$ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789*00\n";
#endif

// speech handler, call from loop()
// plays sequence of wav files
// speakfiles = {"/profilog/speak/file1.wav", "/profilog/speak/file2.wav", ... , NULL };
void speech()
{
  static uint32_t tprev_wav = t_ms, tprev_wavp = t_ms;
  static uint32_t tspeak_ready;
  uint32_t tdelta_wav, tdelta_wavp;
  if (speakfile == NULL && pcm_is_open == 0) // do we have more files to speak?
  {
    if(speakfiles)
      if(*speakfiles)
        speakfile = *speakfiles++;
  }
  // before starting new word we must check
  // that previous word has been spoken
  // both speech end timing methods work
#if 1
  // coarse estimate of speech end
  tdelta_wavp = t_ms - tprev_wavp; // estimate time after last word is spoken
  if (speakfile != NULL && pcm_is_open == 0 && tdelta_wavp > 370) // 370 ms after last word
#else
  // fine estimate of speech end
  if (speakfile != NULL && pcm_is_open == 0 && (((int32_t)t_ms) - (int32_t)tspeak_ready) > 0) // NULL: we are ready to speak new file,
#endif
  {
    // start speech
    mount();
    open_pcm(speakfile); // load buffer with start of the file
    tprev_wavp = ms(); // reset play timer from now, after start of PCM file
    tspeak_ready = tprev_wavp+370;
    tprev_wav = t_ms; // prevent too often starting of the speech
  }
  else
  {
    // continue speaking from remaining parts of the file
    // refill wav-play buffer
    tdelta_wavp = t_ms - tprev_wavp; // how many ms have passed since last refill
    if (tdelta_wavp > 200 && pcm_is_open) // 200 ms is about 2.2KB to refill
    {
      int remaining_bytes;
      remaining_bytes = play_pcm(tdelta_wavp * 11); // approx 11 samples per ms at 11025 rate
      tprev_wavp = t_ms;
      if (!pcm_is_open)
      {
        speakfile = NULL; // consumed
        tspeak_ready = t_ms + remaining_bytes / 11 + 359; // estimate when PCM will be ready
      }
    }
  }
}

#if 0
// terminal mode
void loop_obd() {
  if (Serial.available()) {
    SerialBT.write(Serial.read());
    delay(20); // OBD needs slow char-by-char input
  }
  if (SerialBT.available()) {
    Serial.write(SerialBT.read());
  }
  speech();
}
#endif

void report_search(void)
{
  if (*speakfiles == NULL && pcm_is_open == 0) // NULL: we are ready to speak new file,
  {
    // After 7s silence, report searching for GPS/OBD.
    // It must speak early to finish before reconnect.
    // At 10s silence bluetooth recoonect starts.
    // During reconnect, CPU is busy and can not 
    // feed speech data.
    if(line_tdelta > 7000 && speak_search > 0)
    {
      if(mode_obd_gps)
        speakaction[0] = "/profilog/speak/searchobd.wav";
      else
        speakaction[0] = "/profilog/speak/searchgps.wav";
      speakaction[1] = sensor_status_file[sensor_check_status]; // normal
      #if 0 // debug false report all combinations no sensors
      static uint8_t x = 0;
      if(++x > 2) x = 0;
      speakaction[1] = sensor_status_file[x];
      #endif
      speakfiles = speakaction;
      speak_search = 0; // consumed, next BT connect will enable it
    }
  }
}

// every 100m travel report IRI
// with speech and RDS
void report_iri(void)
{
  if (travel100m_prev != travel100m) // normal: update RDS every 100 m
  {
    travel100m_prev = travel100m;
    uint8_t iri99 = iriavg*10;
    if(iri99 > 99)
      iri99 = 99;
    iri2digit[0]='0'+iri99/10;
    iri2digit[2]='0'+iri99%10;
    rds_message(&tm);
    if (speakfile == NULL && pcm_is_open == 0 && fast_enough > 0)
    {
      speak2digits[0] = digit_file[iri2digit[0]-'0'];
      speak2digits[1] = digit_file[iri2digit[2]-'0'];
      int balance = 0;
      if(sensor_check_status == 3)
        balance = (srvz[0]>>1) > srvz[1] ? 1
                : (srvz[1]>>1) > srvz[0] ? 2
                : 0;
      speak2digits[2] = sensor_balance_file[balance];
      speakfiles = speak2digits;
    }
  }
}

// every minute report status
// with speech and RDS
// search, signal, sensor presence
void report_status(void)
{
  static uint8_t prev_min;
  if (tm.tm_min != prev_min)
  { // speak every minute
    // TODO this file save parts should go to
    // separate function
    flush_logs(); // save data just in case
    if (speakfile == NULL && *speakfiles == NULL && pcm_is_open == 0)
    {
      rds_message(&tm);
      if (speed_ckt < 0) // no signal
      {
        speakaction[0] = "/profilog/speak/wait.wav";
        speakaction[1] = sensor_status_file[sensor_check_status];
      }
      else
      {
        if (fast_enough)
        {
          //speakaction[0] = "/profilog/speak/record.wav";
          speakaction[0] = sensor_status_file[sensor_check_status];
          speakaction[1] = NULL;
        }
        else
        {
          speakaction[0] = "/profilog/speak/ready.wav";
          speakaction[1] = sensor_status_file[sensor_check_status];
        }
      }
      speakfiles = speakaction;
      speak_search = 0;
    }
    prev_min = tm.tm_min;
  }
}

// tm must be set now
// open logs if fast enough
// when reconnected it's a new "session"
// and logs are open with new filename
// from tm_session timestamp
void handle_session_log(void)
{
  if(fast_enough)
  {
    if(session_log == 0)
    {
      tm_session = tm;
      session_log = 1;
    }
    if(session_log != 0)
    {
      mount();
      open_logs(&tm_session);
    }
  }
}

// calculate travel from
// speed and internal timer
void travel_ct0(void)
{
  if(fast_enough)
  {
    int travel_dt = ((int32_t) ct0) - ((int32_t) ct0_prev); // ms since last time
    if(travel_dt < 10000) // ok reports are below 10s difference
      travel_mm += speed_mms * travel_dt / 1000;
    travel100m = travel_mm / 100000; // normal: report every 100 m
    //travel100m = travel_mm / 1000; // debug: report every 1 m
  }
  // set ct0_prev always (also when stopped)
  // to prevent building large delta time when fast enough
  ct0_prev = ct0; // for travel_dt
}

void handle_fast_enough(void)
{
  if (speed_kmh > KMH_START) // normal
  {
    if (fast_enough == 0)
    {
      Serial.print(speed_kmh);
      Serial.println(" km/h fast enough - start logging");
    }
    fast_enough = 1;
  }
  if (speed_kmh < KMH_STOP && speed_kmh >= 0) // normal
  { // tunnel mode: ignore negative speed (no signal) when fast enough
    if (fast_enough)
    {
      write_stop_delimiter();
      close_logs(); // save data in case of power lost
      write_last_nmea();
      stopcount++;
      Serial.print(speed_kmh);
      Serial.println(" km/h not fast enough - stop logging");
      travel_mm = 0; // we stopped, reset travel
    }
    fast_enough = 0;
  }
}

void get_iri(void)
{
  spi_srvz_read(srvz);
  const float srvz2iri = 2.5e-6; // (1e-3 * 0.25/100)
  iri[0] = srvz[0]*srvz2iri;
  iri[1] = srvz[1]*srvz2iri;
  iriavg = sensor_check_status == 0 ? 0.0
         : sensor_check_status == 1 ? iri[0]
         : sensor_check_status == 2 ? iri[1]
         : (iri[0]+iri[1])/2;  // 3, average of both sensors
  #if 0
  // calculated at report every 100m to save CPU cycles
  iri_balance = 0;
  if(sensor_check_status == 3)
    iri_balance = (srvz[0]>>1) > srvz[1] ? 1 //  left > 2*right
                : (srvz[1]>>1) > srvz[0] ? 2 // right > 2*left
                : 0;
  #endif
}

void handle_reconnect(void)
{
  close_logs();
  write_last_nmea();
  session_log = 0; // request new timestamp file name when reconnected
  //ls();
  finalize_data(&tm); // finalize all except current session (if one file per day)
  umount();

  mode_obd_gps ^= 1; // toggle mode 0:OBD 1:GPS
  String   bt_name     = mode_obd_gps ? GPS_NAME : OBD_NAME;
  uint8_t *mac_address = mode_obd_gps ? GPS_MAC  : OBD_MAC;
  rds_message(NULL);
  //Serial.print("trying mode ");
  //Serial.println(mode_obd_gps);

  // connect(address) is fast (upto 10 secs max), connect(name) is slow (upto 30 secs max) as it needs
  // to resolve name to address first, but it allows to connect to different devices with the same name.
  // Set CoreDebugLevel to Info to view devices bluetooth address and device names

  if(bt_name.length())
    connected = SerialBT.connect(bt_name); // 30s connect with String name
  else
    connected = SerialBT.connect(mac_address); // 15s connect with uint8_t GPS_MAC[6] but some devices reboot esp32

  // return value "connected" doesn't mean much
  // it is sometimes true even if not connected.
  line_terminator = mode_obd_gps ? '\n' : '\r';
  obd_retry = ~0; // initial retry OBD to start reports
  datetime_is_set = 0; // set datetime again
  line_i = 0; // reset line buffer write pointer
  speak_search = 1; // request speech report on searching for GPS/OBD
}

void travel_gps(void)
{
  if(fast_enough)
  {
    int travel_dt = (864000 + daytime - daytime_prev) % 864000; // seconds*10 since last time
    if(travel_dt < 100) // ok reports are below 10s difference
      travel_mm += speed_mms * travel_dt / 10;
    travel100m = travel_mm / 100000; // normal: report every 100 m
  }
  daytime_prev = daytime; // for travel_dt
}

// log nmea time for PPS phase lock
void nmea_time_log(void)
{
  daytime = nmea2s(line + 7); // x10, 0.1s resolution
  int32_t nmea2ms = daytime * 100 - ct0; // difference from nmea to timer
  if (nmea2ms_sum == 0) // sum is 0 only at reboot
    init_nmea2ms(nmea2ms); // speeds up convergence
  nmea2ms_sum += nmea2ms - nmea2ms_log[inmealog]; // moving sum
  nmea2ms_dif = nmea2ms_sum / 256;
  nmea2ms_log[inmealog++] = nmea2ms;
}

// from nmea line draw a kml line,
// remembers last point, keeps alternating 2-points
void draw_kml_line(char *line)
{
  struct int_latlon ilatlon;
  static int ipt = 0; // current point index, alternates 0/1
  static char timestamp[23] = "2000-01-01T00:00:00.0Z";
  if(log_wav_kml&2)
  { // only if kml mode is enabled, save CPU if when not enabled
    strcpy(lastnmea, line); // copy line to last nmea as tmp buffer (overwritten by parser)
    // parse lastnmea -> ilatlon (parsing spoils nmea string)
    nmea2latlon(lastnmea, &ilatlon);
    float *lat = &(x_kml_line->lat[ipt]);
    float *lon = &(x_kml_line->lon[ipt]);
    *lat = ilatlon.lat_deg + abs(ilatlon.lat_umin)*1.66666666e-8;
    if(ilatlon.lat_umin < 0)
      *lat = -*lat;
    *lon = ilatlon.lon_deg + abs(ilatlon.lon_umin)*1.66666666e-8;
    if(ilatlon.lon_umin < 0)
      *lon = -*lon;
    x_kml_line->value = iriavg;
    x_kml_line->left  = iri[0];
    x_kml_line->right = iri[1];
    x_kml_line->speed_kmh = speed_mms*3.6e-3;
    nmea2kmltime(line, timestamp);
    x_kml_line->timestamp = timestamp;
    kml_line(x_kml_line);
    if(travel100m_prev != travel100m) // every 100m draw arrow
    {
      x_kml_arrow->lat   = *lat;
      x_kml_arrow->lon   = *lon;
      x_kml_arrow->value = iriavg;
      x_kml_arrow->left  = iri[0];
      x_kml_arrow->right = iri[1];
      x_kml_arrow->speed_kmh = x_kml_line->speed_kmh;
      char *b = nthchar(line, 8, ','); // position to heading
      char str_heading[5] = "0000"; // storage for parsing
      str_heading[0] = b[1];
      str_heading[1] = b[2];
      str_heading[2] = b[3];
      str_heading[3] = b[5]; // skip b[4]=='.'
      //str_heading[4] = 0;
      int iheading = strtol(str_heading, NULL, 10); // parse as integer
      x_kml_arrow->heading   = iheading*0.1; // convert to float
      x_kml_arrow->timestamp = timestamp;
      kml_arrow(x_kml_arrow);
    }
    write_log_kml(0); // normal
    //write_log_kml(1); // debug (for OBD)
    ipt ^= 1; // toggle 0/1
  }
}

void handle_gps_line_complete(void)
{
  line[line_i-1] = 0; // replace \n termination with 0
  //if(nmea[1]=='P' && nmea[3]=='R') // print only $PGRMT, we need Version 3.00
  if ((line_i > 50 && line_i < 90) // accept lines of expected length
          && (line[1] == 'G' // accept 1st letter is G
              && (line[4] == 'M' /*|| nmea[4]=='G'*/))) // accept 4th letter is M or G, accept $GPRMC and $GPGGA
  {
    if (check_nmea_crc(line)) // filter out NMEA sentences with bad CRC
    {
      // there's bandwidth for only one NMEA sentence at 10Hz (not two sentences)
      // time calculation here should receive no more than one NMEA sentence for one timestamp
      write_tag(line);
      //Serial.println(line); // debug
      speed_ckt = nmea2spd(line); // parse speed to centi-knots, -1 if no signal
      if(KMH_BTN) // debug
      {
        int btn = spi_btn_read();    // debug
        if((btn & 4)) speed_ckt = KMH_BTN*54; // debug BTN2 4320 ckt = 80 km/h = 22 m/s
        if((btn & 8)) speed_ckt = -1;   // debug BTN3 tunnel, no signal
      }
      if(speed_ckt >= 0) // for tunnel mode keep speed if no signal (speed_ckt < 0)
      {
        speed_mms = (speed_ckt *  5268) >> 10;
        speed_kmh = (speed_ckt * 19419) >> 20;
      }
      spi_speed_write(fast_enough > 0 && speed_kmh > 6 ? speed_mms : 0);
      nmea_time_log();
      write_logs();
      handle_fast_enough();
      if (nmea2tm(line, &tm))
      {
        get_iri();
        char iri_tag[40];
        sprintf(iri_tag, " L%05.2fR%05.2f*00 ",
          iri[0]>99.99?99.99:iri[0], iri[1]>99.99?99.99:iri[1]);
        write_nmea_crc(iri_tag+1);
        write_tag(iri_tag);
        set_date_from_tm(&tm);
        handle_session_log(); // will open logs if fast enough (new filename when reconnected)
        travel_gps(); // calculate travel length
        draw_kml_line(line);
        strcpy(lastnmea, line); // copy line to last nmea for storage
        report_iri();
        report_status();
      }
    }
  }
}

// convert OBD reading to a fake NMEA line
// and proceed same as NMEA
void handle_obd_line_complete(void)
{
  //line[line_i-1] = 0; // replace \r termination with 0
  //write_tag(line); // debug
  //Serial.println(line); // debug
  if(KMH_BTN) // debug
  if(line[1] == 'E') // match 'E' in "SEARCHING"
  {
    strcpy(line, "00 00 00"); // debug last hex represents 0 km/h
    int btn = spi_btn_read(); // debug
    if((btn & 4)) sprintf(line, "00 00 %02X", KMH_BTN); // debug BTN2 default 80 km/h
  }
  if(line_i > 0 && line[line_i-1] == prompt_obd)
    SerialBT.print(obd_request_kmh); // next request
  else
  if(line[0] == 'S' // strcmp(line,"STOPPED") == 0
  || line[0] == 'U' // strcmp(line,"UNABLE TO CONNECT") == 0
  || line[0] == 'N' // strcmp(line,"NO DATA") == 0
  || line[0] == 'E' // strcmp(line,"ERR93") == 0
  )
    speed_kmh = -1; // negative means no signal (engine not connected)
  else
  if(line_i >= 8 && line[5] == ' ') // >8 bytes long and 5th byte is space
    // "00 00 00" ignore first 2 hex, last 3rd hex integer km/h
    // parse last digit
    speed_kmh = strtol(line+6, NULL ,16); // normal
  speed_mms = (speed_kmh * 284444) >> 10; // mm/s
  speed_ckt = (speed_kmh *  52679) >> 10; // centi-knots
  spi_speed_write(fast_enough ? speed_mms : 0); // normal

  if(speed_kmh > 0)
  {
    char iri_tag[120]; // fake time and location
    int travel_lat = (travel_mm * 138)>>8; // coarse approximate mm to microminutes
    int travel_lon = stopcount << 16; // microminutes position next line using stopcount
    struct int_latlon fake_latlon;
    get_iri();
    fake_latlon.lat_deg  = last_latlon.lat_deg  + (abs(last_latlon.lat_umin) + travel_lat)/60000000;
    fake_latlon.lat_umin =                        (abs(last_latlon.lat_umin) + travel_lat)%60000000;
    fake_latlon.lon_deg  = last_latlon.lon_deg  + (abs(last_latlon.lon_umin) + travel_lon)/60000000;
    fake_latlon.lon_umin =                        (abs(last_latlon.lon_umin) + travel_lon)%60000000;
    // this fake NMEA has the same format like real NMEA from GPS
    // different is magnetic north, here is 000.0, GPS has nonzero like 003.4
    sprintf(iri_tag,
" $GPRMC,%02d%02d%02d.0,V,%02d%02d.%06d,%c,%03d%02d.%06d,%c,%03d.%02d,000.0,%02d%02d%02d,000.0,E,N*00 L%05.2fR%05.2f*00 ",
          tm.tm_hour, tm.tm_min, tm.tm_sec,      // hms
          fake_latlon.lat_deg,
          abs(fake_latlon.lat_umin)/1000000,
          abs(fake_latlon.lat_umin)%1000000,
          fake_latlon.lat_umin >= 0 ? 'N' : 'S',
          fake_latlon.lon_deg,
          abs(fake_latlon.lon_umin)/1000000,
          abs(fake_latlon.lon_umin)%1000000,
          fake_latlon.lon_umin >= 0 ? 'E' : 'W',
          speed_ckt/100, speed_ckt%100,
          tm.tm_mday, tm.tm_mon+1, tm.tm_year%100,   // dmy
          iri[0]>99.99?99.99:iri[0], iri[1]>99.99?99.99:iri[1]
    );
    write_nmea_crc(iri_tag+1); // CRC for NMEA part
    // safety check for space at expected place, sprintf length can be unpredictable
    if(iri_tag[80] == ' ')
      write_nmea_crc(iri_tag+80); // CRC for IRI part
    //Serial.println(iri_tag+81); // debug
    write_tag(iri_tag);
    travel_ct0();
    iri_tag[80] = 0; // null terminate for lastnmea save
    draw_kml_line(iri_tag+1); // for kml file generation
    strcpy(lastnmea, iri_tag+1); // for saving last nmea line
  }
  write_logs(); // use SPI_MODE1
  handle_fast_enough(); // will close logs if not fast enough
  getLocalTime(&tm, NULL);
  handle_session_log(); // will open logs if fast enough (new filename when reconnected)
  report_iri();
  report_status();
  obd_retry = ~0;
}

void handle_obd_silence(void)
{
  if(!connected)
    return;
  if(line_tdelta > 7000 && (obd_retry & 1) != 0)
  {
    SerialBT.print(obd_request_kmh); // read speed km/h (without car, should print "SEARCHING...")
    obd_retry &= ~1;
  }
  #if 0
  else
  if(line_tdelta > 12000 && (obd_retry & 2) != 0)
  {
    SerialBT.print(obd_request_kmh); // read speed km/h (without car, should print "SEARCHING...")
    obd_retry &= ~2;
  }
  #endif
}

void loop_run(void)
{
  char c;
  t_ms = ms();
  line_tdelta = t_ms - line_tprev;
  // handle incoming data as lines and reconnect on 10s silence
  if (connected && SerialBT.available() > 0)
  {
    c = 0;
    while(SerialBT.available() > 0 && c != line_terminator && c != prompt_obd) // line not complete
    {
      if (line_i == 0)
        ct0 = ms(); // time when first char in line came
      // read returns char or -1 if unavailable
      c = SerialBT.read();
      if (line_i < sizeof(line) - 3)
        line[line_i++] = c;
    }
    if(c == line_terminator || c == prompt_obd ) // line complete
    { // GPS has '\n', OBD has '\r' line terminator and '>' prompt
      line[line_i] = 0; // additionally null-terminate string
      if(mode_obd_gps)
        handle_gps_line_complete();
      else
        handle_obd_line_complete();
      line_tprev = t_ms; // record time, used to detect silence
      line_i = 0; // line consumed, start new
      // BT LED ON
      pinMode(PIN_LED, OUTPUT);
      digitalWrite(PIN_LED, LED_ON);
    }
  }
  if(mode_obd_gps == 0)
    handle_obd_silence();
  // (*handle_silence)(); // in OBD mode this will retry sending data query

  // finale check for serial line silence to determine if
  // GPS/OBD needs to be reconnected
  // reported 15s silence is possible http://4river.a.la9.jp/gps/report/GLO.htm
  // for practical debugging we wait for less here

  if (line_tdelta > 10000) // 10 seconds of serial silence? then reconnect
  {
      // BT LED OFF
      pinMode(PIN_LED, INPUT);
      digitalWrite(PIN_LED, LED_OFF);
      //Serial.println("reconnect");
      handle_reconnect();
      // reconnect has waited too much, we must reload t_ms
      // this will prevent immediately GPS search,
      // give it 2s to start feeding data
      t_ms = ms();
      line_tprev = t_ms;
      line_tdelta = 0;
  }
  else
    write_logs();
  report_search();
  speech(); // runs speech PCM
}

void speak_report_ip(struct tm *tm)
{
  if(tm->tm_sec%20 == 0) // speak every 20s
  if(speakfile == NULL && *speakfiles == NULL && pcm_is_open == 0)
  {
    String str_IP = WiFi.localIP().toString();
    const char *c_str_IP = str_IP.c_str();
    int i, n = str_IP.length();
    if(n > 15)
      n = 15;
    for(i = 0; i < n; i++)
    {
      char c = c_str_IP[i];
      if(c >= '0' && c <= '9')
        speakip[i] = digit_file[c-'0'];
      else
        speakip[i] = "/profilog/speak/point.wav";
    }
    speakip[i] = NULL; // terminator
    speakfiles = speakip;
  }
}

void loop_web(void)
{
  t_ms = ms();
  server.handleClient();
  int is_connected = monitorWiFi();
  getLocalTime(&tm, NULL);
  rds_report_ip(&tm);
  if(is_connected)
    speak_report_ip(&tm);
  speech();
}

void loop(void)
{
  (*loop_pointer)();
}
