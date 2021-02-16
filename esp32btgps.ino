#include "BluetoothSerial.h"
// set Board->ESP32 Arduino->ESP32 Dev Module

#define LED_BUILTIN 2
#define GPIO_PWM0A_OUT 27

#include "soc/mcpwm_reg.h"
#include "soc/mcpwm_struct.h"
#include "driver/mcpwm.h"

BluetoothSerial SerialBT;

uint8_t address[6] = {0x10, 0xC6, 0xFC, 0x84, 0x35, 0x2E};
String name = "Garmin GLO #4352e";
char *pin = "1234"; //<- standard pin would be provided by default
bool connected = false;

void setup() {
  Serial.begin(115200);
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, 0);
  SerialBT.begin("ESP32", true);
  SerialBT.setPin(pin);
  Serial.println("Bluetooth master started");

  mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM0A, GPIO_PWM0A_OUT);     // Initialise channel MCPWM0A on GPIO pin 27
  MCPWM0.clk_cfg.prescale = 199;                // Set the 160MHz clock prescaler to 199 (160MHz/(199+1)=800kHz)
  MCPWM0.timer[0].period.prescale = 199;        // Set timer 0 prescaler to 199 (800kHz/(199+1))=4kHz)
  MCPWM0.timer[0].period.period = 3999;         // Set the PWM period to 1Hz (4kHz/(3999+1)=1Hz) 
  MCPWM0.channel[0].cmpr_value[0].val = 2000;   // Set the counter compare for 50% duty-cycle
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
  t = millis();
  int16_t tms = (int16_t)(t-tprev);

  if (connected && SerialBT.available())
  {
    // read returns char or -1 if unavailable
    char b = SerialBT.read();
    Serial.print(b);
    digitalWrite(LED_BUILTIN,1);
    tprev=t;
  }
  else
  {
    if(tms > 4000) // 4 seconds of serial silence
    {
      digitalWrite(LED_BUILTIN,0);
      reconnect();
      tprev = millis();
    }
  }
}
