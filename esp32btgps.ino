#include "BluetoothSerial.h"
// set Board->ESP32 Arduino->ESP32 Dev Module

// BTN has inverted logic, 0 when pressed
#define PIN_BTN 0
#define PIN_LED 2
#define PIN_PPS 27


#define CAP1_INT_EN BIT(27)  //Capture 0 interrupt bit
#define CAP2_INT_EN BIT(28)  //Capture 1 interrupt bit
#define GPIO_CAP1_IN   gpio_num_t(23)   //Set GPIO 23 as  CAP0
#define GPIO_CAP2_IN   gpio_num_t(25)   //Set GPIO 25 as  CAP1

#include "soc/mcpwm_reg.h"
#include "soc/mcpwm_struct.h"
#include "driver/mcpwm.h"

BluetoothSerial SerialBT;

uint8_t address[6] = {0x10, 0xC6, 0xFC, 0x84, 0x35, 0x2E};
String name = "Garmin GLO #4352e";
char *pin = "1234"; //<- standard pin would be provided by default
bool connected = false;

/*
static void IRAM_ATTR isr_handler(void *x)
{
  mcpwm_capture_signal_get_value(MCPWM_UNIT_0, MCPWM_SELECT_CAP1);
  Serial.println("interrupt");
  MCPWM0.int_clr.val = CAP1_INT_EN;
}
*/

void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BTN, INPUT);
  digitalWrite(PIN_LED, 0);
  SerialBT.begin("ESP32", true);
  SerialBT.setPin(pin);
  Serial.println("Bluetooth master started");

  mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM0A, PIN_PPS); // Initialise channel MCPWM0A on PPS pin
  MCPWM0.clk_cfg.prescale = 199;                // Set the 160MHz clock prescaler to 199 (160MHz/(199+1)=800kHz)
  MCPWM0.timer[0].period.prescale = 15;         // Set timer 0 prescaler to 15 (800kHz/(15+1))=50kHz)
  MCPWM0.timer[0].period.period = 49999;        // Set the PWM period to 1Hz (50kHz/(49999+1)=1Hz) 
  MCPWM0.channel[0].cmpr_value[0].val = 5000;   // Set the counter compare for 10% duty-cycle
  MCPWM0.channel[0].generator[0].utez = 2;      // Set the PWM0A ouput to go high at the start of the timer period
  MCPWM0.channel[0].generator[0].utea = 1;      // Clear on compare match
  MCPWM0.timer[0].mode.mode = 1;                // Set timer 0 to increment
  MCPWM0.timer[0].mode.start = 2;               // Set timer 0 to free-run
  /*
  //mcpwm_isr_register(MCPWM_UNIT_0, isr_handler, NULL, ESP_INTR_FLAG_IRAM, NULL); // not working
  //MCPWM0.int_ena.val = CAP1_INT_EN;
  //mcpwm_capture_enable(MCPWM_UNIT_0, MCPWM_SELECT_CAP1, MCPWM_POS_EDGE, 80); // prescale by 80 to directly count us
  */
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
  digitalWrite(PIN_LED, digitalRead(PIN_BTN));
  /*
  uint32_t mcpwm_intr_status;
  mcpwm_intr_status = MCPWM0.int_st.val; //Read interrupt status
  if(mcpwm_intr_status)
    Serial.println(mcpwm_intr_status);
  */
  
  if (connected && SerialBT.available())
  {
    // read returns char or -1 if unavailable
    char b = SerialBT.read();
    //Serial.print(b);
    //digitalWrite(PIN_LED,1);
    tprev=t;
  }
  else
  {
    if(tms > 4000) // 4 seconds of serial silence
    {
      //digitalWrite(PIN_LED,0);
      reconnect();
      tprev = millis();
    }
  }
}
