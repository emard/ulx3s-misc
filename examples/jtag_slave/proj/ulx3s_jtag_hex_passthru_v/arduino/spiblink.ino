/* blink and bitbang soft-jtag
*/

// constants won't change. Used here to set a pin number:
const int ledPin =  LED_BUILTIN;// the number of the LED pin

// Variables will change:
int ledState = LOW;             // ledState used to set the LED

// Generally, you should use "unsigned long" for variables that hold time
// The value will quickly become too large for an int to store
unsigned long previousMillis = 0;        // will store last time LED was updated

// constants won't change:
const long interval = 1000;           // interval at which to blink (milliseconds)

#define TCK 14
#define TMS 13
#define TDI 15
#define TDO 12

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

void setup() {
  // set the digital pin as output:
  pinMode(ledPin, OUTPUT);
  Serial.begin(115200);
  pinMode(TCK, OUTPUT);
  pinMode(TMS, OUTPUT);
  pinMode(TDI, OUTPUT);
  pinMode(TDO, INPUT);
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
      bitbang(counter & 0xF, 4);
      ledState = HIGH;
      Serial.println(counter & 0xF);
    } else {
      ledState = LOW;
      counter++;
    }

    // set the LED with the ledState of the variable:
    digitalWrite(ledPin, ledState);
  }
}
