/* SPI-accelerated JTAG and blink */

#include "libxsvf.h"
#include "tap.h"

#include <SPI.h>
static const int spiClk = 30000000; // Hz (30 MHz normal speed)
// static const int spiClk = 200; // Hz (200 Hz debug speed)

//uninitalised pointers to SPI objects
SPIClass * spi_jtag = NULL;

struct libxsvf_host jtaghost;

// constants won't change. Used here to set a pin number:
const int ledPin =  LED_BUILTIN;// the number of the LED pin

// Variables will change:
int ledState = LOW;             // ledState used to set the LED

// Generally, you should use "unsigned long" for variables that hold time
// The value will quickly become too large for an int to store
unsigned long previousMillis = 0;        // will store last time LED was updated

static int interval = 1000; // ms

// JTAG pinout to the SPI-HEX-OLED core
#if 0
#define TCK 14
#define TMS 15
#define TDI 13
#define TDO 12
#endif

#if 0
void bitbang(uint8_t data, uint8_t n)
{
  for(int i = 0; i < n; i++)
  {
    digitalWrite(TCK, 0);
    digitalWrite(TMS, (data & 0x01) != 0 ? 1 : 0);
    digitalWrite(TDI, (data & 0x01) != 0 ? 1 : 0);
    delay(1);
    data >>= 1;
    digitalWrite(TCK, 1);
    delay(1);
  }
  digitalWrite(TCK, 0);  
}
#endif

void prepare_spi_end()
{
  pinMode(TCK, INPUT_PULLDOWN);
  pinMode(TMS, INPUT_PULLDOWN);
  pinMode(TDI, INPUT_PULLDOWN);
  pinMode(TDO, INPUT_PULLDOWN);
}

void init_bitbang_pins()
{
  digitalWrite(TCK, 0);
  digitalWrite(TMS, 0);
  digitalWrite(TDI, 0);
  // for bitbanging
  pinMode(TCK, OUTPUT);
  pinMode(TMS, OUTPUT);
  pinMode(TDI, OUTPUT);
  pinMode(TDO, INPUT);
  digitalWrite(TCK, 0);
  digitalWrite(TMS, 0);
  digitalWrite(TDI, 0);
}

void jtag_nibble(uint8_t data)
{
  uint32_t data_mosi, data_miso;
  data_mosi = data;
  //spi_jtag->beginTransaction(SPISettings(spiClk, LSBFIRST, SPI_MODE0));
  spi_jtag->transferBits(data_mosi, &data_miso, 4);
  //spi_jtag->endTransaction();
}

void jtag_byte(uint8_t data)
{
  uint8_t data_miso[8];
  uint8_t data_mosi[8] = { 0x10, 0x32, 0x54, 0x76, 0x98, 0xBA, 0xDC, 0xFE };
  data_mosi[0] = data;
  //spi_jtag->beginTransaction(SPISettings(spiClk, LSBFIRST, SPI_MODE0));
  spi_jtag->transferBytes(data_mosi, data_miso, 4);
  //spi_jtag->endTransaction();
}

void setup() {
  prepare_spi_end();
  init_bitbang_pins();

  // set the digital pin as output:
  pinMode(ledPin, OUTPUT);
  Serial.begin(115200);

  spi_jtag = new SPIClass(VSPI); // VSPI or HSPI can be used

  //initialise HSPI with default pins
  //SCLK = 14, MISO = 12, MOSI = 13, SS = 15
  //spi_jtag->begin();
  //alternatively route through GPIO pins
  //spi_jtag->begin(25, 26, 27, 32); //SCLK, MISO, MOSI, SS
  // set SS = 0 to disable hardware driving of SS pin
  // software will drive it using digitalWrite()
  spi_jtag->begin(TCK, TDO, TDI, 0); // SCLK, MISO, MOSI, SS
  spi_jtag->beginTransaction(SPISettings(spiClk, LSBFIRST, SPI_MODE0));
  // when done with transaction:
  // spi_jtag->endTransaction();
  // when done with jtag close the SPI port completely
  // spi_jtag->end();

  jtaghost.tap_state = LIBXSVF_TAP_INIT;
  libxsvf_tap_walk(&jtaghost, LIBXSVF_TAP_RESET);
  libxsvf_tap_walk(&jtaghost, LIBXSVF_TAP_IDLE);
}

void loop() {
  static uint32_t counter;
  // here is where you'd put code that needs to be running all the time.

  // check to see if it's time to blink the LED; that is, if the difference
  // between the current time and last time you blinked the LED is bigger than
  // the interval at which you want to blink the LED.
  unsigned long currentMillis = millis();

  if (currentMillis - previousMillis >= interval) {
    // save the last time you blinked the LED
    previousMillis = currentMillis;

    // if the LED is off turn it on and vice-versa:
    if (ledState == LOW) {
      #if 0
      digitalWrite(TMS, 0);
      jtag_nibble(0xA); // 4-bit header 0xA
      digitalWrite(TMS, 1);
      jtag_byte(counter & 0xFF); // 8-bit counter
      digitalWrite(TMS, 0);
      jtag_nibble(0xB); // 4-bit footer 0xB
      #endif
      ledState = HIGH;
      Serial.println(counter & 0xF);
      libxsvf_tap_walk(&jtaghost, LIBXSVF_TAP_RESET);
      libxsvf_tap_walk(&jtaghost, LIBXSVF_TAP_IDLE);
    } else {
      ledState = LOW;
      counter++;
      libxsvf_tap_walk(&jtaghost, LIBXSVF_TAP_DRSELECT);
      libxsvf_tap_walk(&jtaghost, LIBXSVF_TAP_DRCAPTURE);
    }

    // set the LED with the ledState of the variable:
    digitalWrite(ledPin, ledState);
  }
}
