# Cables and connectors

ADXL355 12-pin male PMOD pinout (parts up, looking at the pins)

|    1    |    2    |    3    |    4    |    5    |    6    |
| ------- | ------- | ------- | ------- | ------- | ------- |
| 01:CS   | 02:MOSI | 03:MISO | 04:SCLK | 05:GND  | 06:3.3V |
| 07:INT1 | 08:NC   | 09:INT2 | 10:DRDY | 11:GND  | 12:3.3V |

14-pin female connector (alignment notch up, looking at the holes).
Pins 1 and 2 of 14-pin cable not connected.
Cable crimped to pins 3-14.

|    1    |    2    |    3    |    4    |    5    |    6    |    7    |
| ------- | ------- | ------- | ------- | ------- | ------- | ------- |
| 01:     | 03:3.3V | 05:GND  | 07:SCLK | 09:MISO | 11:MOSI | 13:CS   |
| 02:     | 04:3.3V | 06:GND  | 08:DRDY | 10:INT2 | 12:NC   | 14:INT1 |

12-pin cable going out of 14-pin female connector:

|   1   |   2   |   3   |   4   |   5   |   6   |   7   |   8   |   9   |  10   |  11   |  12   |
| ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| 3.3V  | 3.3V  |  GND  |  GND  | SCLK  | DRDY  | MISO  | INT2  | MOSI  |  NC   |  CS   | INT1  |

Cable reduction: from 12-pin cable, 3 wires are splitted out
leaving 9 pins to fit DB9 connector:

|   1   |   2   |   3   |   4   |   5   |   6   |   7   |   8   |   9   |  10   |  11   |  12   |
| ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
|       | 3.3V  |  GND  |       | SCLK  | DRDY  | MISO  | INT2  | MOSI  |       |  CS   | INT1  |

DB9 male pinout (note pins mirrored):

|   5   |   9   |   4   |   8   |   3   |   7   |   2   |   6   |   1   |
| ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| 3.3V  |       | SCLK  |       | MISO  |       | MOSI  |       | INT1  |
|       |  GND  |       | DRDY  |       | INT2  |       |  CS   |       |


#    TODO

    [ ] mirror 12-pin, notch down, flat pin 1 align as PMOD pin 1