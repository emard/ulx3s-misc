#include "BluetoothSerial.h"
// set Board->ESP32 Arduino->ESP32 Dev Module

// BTN has inverted logic, 0 when pressed
#define PIN_BTN 0
#define PIN_LED 2
#define PIN_PPS 27
#define PIN_IRQ 26
// PPS and IRQ connected with wire

#include "soc/mcpwm_reg.h"
#include "soc/mcpwm_struct.h"
#include "driver/mcpwm.h"

BluetoothSerial SerialBT;

uint8_t address[6] = {0x10, 0xC6, 0xFC, 0x84, 0x35, 0x2E};
String name = "Garmin GLO #4352e";
char *pin = "1234"; //<- standard pin would be provided by default
bool connected = false;

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
const int16_t period = 1000/PPSHz;
const int16_t halfperiod = period/2;

// rotated log of 256 NMEA timestamps and their cputix timestamps
uint8_t inmealog = 0;
int32_t nmea2ms_log[256]; // difference nmea-millis() log
int64_t nmea2ms_sum;
int32_t nmea2ms_dif;

// nmea timestamp string (day time) from conversion factors to 10x seconds
uint32_t nmea2sx[8] = { 360000,36000,6000,600,100,10,0,1 };

// connect MCPWM PPS pin output to some input pin for interrupt
// workaround to create interrupt at each MCPWM cycle
// the ISR should sample GPS tracking timer and calculate
// MCPWM period correction to make PLL to GPS time
static void IRAM_ATTR isr_handler()
{
  uint32_t ct = cputix(); // hi-resolution timer 18s wraparound
  static uint32_t ctprev;
  uint32_t t = millis();
  static uint32_t tprev;
  int32_t ctdelta2 = (ct - ctprev)/ctMHz; // us time between irq's
  ctprev = ct;
  int16_t phase = (nmea2ms_dif+t)%period;
  int16_t period_correction = (phase_target-phase+2*period+halfperiod)%period-halfperiod;
  if(period_correction < -15 || period_correction > 15)
    period_correction *= 4; // fast convergence
  else
    period_correction /= 4; // slow convergence and hysteresis around 0
  if(period_correction > 1530) // upper limit to prevent 16-bit wraparound
    period_correction = 1530;  
  MCPWM0.timer[0].period.period = Period1Hz+period_correction;
  Serial.print(nmea2ms_dif, DEC); // average nmea time - millis() time
  Serial.print(" ");
  Serial.print(ctdelta2, DEC); // microseconds between each irq measured by CPU timer
  Serial.print(" ");
  Serial.print(phase, DEC); // less:PPS early, more:PPS late
  Serial.println(" irq");
}

/* test 64-bit functions */
#if 0
void test64()
{
  uint64_t G = 1000000000; // 1e9 giga
  uint64_t x = 72*G; // 72e9
  uint64_t r = x+1234;
  uint32_t y = x/G;
  uint32_t z = r%G;
  Serial.println(z, DEC);
}
#endif

// fill sum and log with given difference d
void init_nmea2ms(int32_t d)
{
  // initialize nmea to millis() statistics sum
  nmea2ms_sum = d*256;
  for(int i = 0; i < 256; i++)
    nmea2ms_log[i] = d; 
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED, OUTPUT);
  //pinMode(PIN_BTN, INPUT);
  //attachInterrupt(PIN_BTN, isr_handler, FALLING);
  pinMode(PIN_IRQ, INPUT);
  attachInterrupt(PIN_IRQ, isr_handler, RISING);
  digitalWrite(PIN_LED, 0);
  SerialBT.begin("ESP32", true);
  SerialBT.setPin(pin);
  Serial.println("Bluetooth master started");

  mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM0A, PIN_PPS); // Initialise channel MCPWM0A on PPS pin
  MCPWM0.clk_cfg.prescale = 24;                 // Set the 160MHz clock prescaler to 24 (160MHz/(24+1)=6.4MHz)
  MCPWM0.timer[0].period.prescale = 100/PPSHz-1;// Set timer 0 prescaler to 99 (6.4MHz/(99+1))=64kHz)
  MCPWM0.timer[0].period.period = 63999;        // Set the PWM period to 1Hz (64kHz/(63999+1)=1Hz) 
  MCPWM0.channel[0].cmpr_value[0].val = 6400;   // Set the counter compare for 10% duty-cycle
  MCPWM0.channel[0].generator[0].utez = 2;      // Set the PWM0A ouput to go high at the start of the timer period
  MCPWM0.channel[0].generator[0].utea = 1;      // Clear on compare match
  MCPWM0.timer[0].mode.mode = 1;                // Set timer 0 to increment
  MCPWM0.timer[0].mode.start = 2;               // Set timer 0 to free-run
  init_nmea2ms(0);
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

// convert nmea daytime HHMMSS.S to seconds since midnight x10 (0.1 s resolution)
int nmea2s(char *nmea)
{
  int s = 0;
  for(int i = 0; i < 8; i++)
  s += (nmea[i]-'0')*nmea2sx[i];
  return s;
}

void loop()
{
  static uint32_t tprev;
  uint32_t t = millis();
  static char nmea[256];
  static char c;
  static int i = 0;
  int32_t tdelta = t-tprev;
  static uint32_t ct0; // first char in line millis timestamp

  if (connected && SerialBT.available())
  {
    c=0;
    while(SerialBT.available() && c != '\n')
    {
      if(i == 0)
        ct0 = millis();
      // read returns char or -1 if unavailable
      c = SerialBT.read();
      if(i < 255)
        nmea[i++]=c;
    }
    if(i > 3 && c == '\n') // line complete
    {
      //if(nmea[1]=='P' && nmea[3]=='R') // print only PGRMT, we need Version 3.00
      if(nmea[1]=='G' && nmea[3]=='R') // print only GPRMC
      {
        nmea[i]=0;
        //Serial.print(nmea);
        int daytime = nmea2s(nmea+7);
        int32_t nmea2ms = daytime*100-ct0; // difference from nmea to timer
        if(nmea2ms_sum == 0) // sum is 0 only at reboot
          init_nmea2ms(nmea2ms); // speeds up convergence
        nmea2ms_sum += nmea2ms-nmea2ms_log[inmealog]; // moving sum
        nmea2ms_dif = nmea2ms_sum/256;
        nmea2ms_log[inmealog++] = nmea2ms;        
        //Serial.println(daytime, DEC);
        //Serial.println(ct, HEX);
      }
      digitalWrite(PIN_LED,1);
      tprev=t;
      i=0;
    }
  }
  else
  {
    if(tdelta > 4000) // 4 seconds of serial silence
    {
      digitalWrite(PIN_LED,0);
      reconnect();
      tprev = millis();
      i=0;
    }
  }
}