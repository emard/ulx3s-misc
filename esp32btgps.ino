#include "BluetoothSerial.h"
// set Board->ESP32 Arduino->ESP32 Dev Module

// BTN has inverted logic, 0 when pressed
#define PIN_BTN 0
#define PIN_LED 2
#define PIN_PPS 27

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

// connect MCPWM PPS pin output to some input pin for interrupt
// workaround to create interrupt at each MCPWM cycle
// the ISR should sample GPS tracking timer and calculate
// MCPWM period correction to make PLL to GPS time
static void IRAM_ATTR isr_handler()
{
  Serial.println("interrupt");
}


void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BTN, INPUT);
  attachInterrupt(PIN_BTN, isr_handler, FALLING);
  digitalWrite(PIN_LED, 0);
  SerialBT.begin("ESP32", true);
  SerialBT.setPin(pin);
  Serial.println("Bluetooth master started");

  mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM0A, PIN_PPS); // Initialise channel MCPWM0A on PPS pin
  MCPWM0.clk_cfg.prescale = 24;                 // Set the 160MHz clock prescaler to 24 (160MHz/(24+1)=6.4MHz)
  MCPWM0.timer[0].period.prescale = 99;         // Set timer 0 prescaler to 99 (6.4MHz/(99+1))=64kHz)
  MCPWM0.timer[0].period.period = 63999;        // Set the PWM period to 1Hz (64kHz/(63999+1)=1Hz) 
  MCPWM0.channel[0].cmpr_value[0].val = 6400;   // Set the counter compare for 10% duty-cycle
  MCPWM0.channel[0].generator[0].utez = 2;      // Set the PWM0A ouput to go high at the start of the timer period
  MCPWM0.channel[0].generator[0].utea = 1;      // Clear on compare match
  MCPWM0.timer[0].mode.mode = 1;                // Set timer 0 to increment
  MCPWM0.timer[0].mode.start = 2;               // Set timer 0 to free-run
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

void loop()
{
  static uint16_t tprev, t;
  static char nmea[256];
  static char c;
  static int i = 0;
  t = millis();
  int16_t tms = (int16_t)(t-tprev);
  uint32_t ct = cputix();

  if (connected && SerialBT.available())
  {
    c=0;
    while(SerialBT.available() && c != '\n')
    {
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
        Serial.print(nmea);
        //Serial.println(ct, HEX);
      }
      digitalWrite(PIN_LED,1);
      tprev=t;
      i=0;
    }
  }
  else
  {
    if(tms > 4000) // 4 seconds of serial silence
    {
      digitalWrite(PIN_LED,0);
      reconnect();
      tprev = millis();
      i=0;
    }
  }
}
