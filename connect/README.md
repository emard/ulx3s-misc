# Cables and connectors

ADXL355 12-pin PMOD pinout (parts up, looking at the pins)

|    1    |    2    |    3    |    4    |    5    |    6    |
| ------- | ------- | ------- | ------- | ------- | ------- |
| 01:CS   | 02:MOSI | 03:MISO | 04:SCLK | 05:GND  | 06:3.3V |
| 07:INT1 | 08:NC   | 09:INT2 | 10:DRDY | 11:GND  | 12:3.3V |

14-pin connector: Pins 1 and 2 of 14-pin cable not connected.
Cable crimped to pins 3-14. 14-pin pinout alignment notch up,
looking to the holes (mirror of pins).

|    1    |    2    |    3    |    4    |    5    |    6    |    7    |
| ------- | ------- | ------- | ------- | ------- | ------- | ------- |
| 01:     | 03:3.3V | 05:GND  | 07:SCLK | 09:MISO | 11:MOSI | 13:CS   |
| 02:     | 04:3.3V | 06:GND  | 08:DRDY | 10:INT2 | 12:NC   | 14:INT1 |

12-pin cable going out of 14-pin connector:

|   1   |   2   |   3   |   4   |   5   |   6   |   7   |   8   |   9   |  10   |  11   |  12   |
| ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| 3.3V  | 3.3V  |  GND  |  GND  | SCLK  | DRDY  | MISO  | INT2  | MOSI  |  NC   |  CS   | INT1  |

DB9 cable crimping: some wires from 12-pin cable splitted out
and not going to DB9 connector, resulting in 9-pin cable:

|   1   |   2   |   3   |   4   |   5   |   6   |   7   |   8   |   9   |  10   |  11   |  12   |
| ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
|       | 3.3V  |  GND  |       | SCLK  | DRDY  | MISO  | INT2  | MOSI  |       |  CS   | INT1  |
