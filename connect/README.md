# Cables and connectors

ADXL355 12-pin male PMOD pinout (parts up, looking at the pins)

|    1    |    2    |    3    |    4    |    5    |    6    |
| ------- | ------- | ------- | ------- | ------- | ------- |
| 01:CS   | 02:MOSI | 03:MISO | 04:SCLK | 05:GND  | 06:3.3V |
| 07:INT1 | 08:NC   | 09:INT2 | 10:DRDY | 11:GND  | 12:3.3V |

14-pin female connector (alignment notch down, looking at the holes).
Pins 13 and 14 of 14-pin cable not connected.
Cable crimped to pins 1-12.

|    1    |    2    |    3    |    4    |    5    |    6    |    7    |
| ------- | ------- | ------- | ------- | ------- | ------- | ------- |
| 02:CS   | 04:MOSI | 06:MISO | 08:SCLK | 10:GND  | 12:3.3V | 14:     |
| 01:INT1 | 03:NC   | 05:INT2 | 07:DRDY | 09:GND  | 11:3.3V | 13:     |

12-pin cable going out of 14-pin female connector:

|   1   |   2   |   3   |   4   |   5   |   6   |   7   |   8   |   9   |  10   |  11   |  12   |
| ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| INT1  |  CS   |  NC   | MOSI  | INT2  | MISO  | DRDY  | SCLK  |  GND  |  GND  | 3.3V  | 3.3V  |

Cable reduction: from 12-pin cable, peel out 3 wires,
leaving 9 pins to fit into DB9 connector:

|   1   |   2   |   3   |   4   |   5   |   6   |   7   |   8   |   9   |  10   |  11   |  12   |
| ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| INT1  |  CS   |       | MOSI  | INT2  | MISO  | DRDY  | SCLK  |       |  GND  | 3.3V  |       |

DB9 male pinout:

|   1   |   6   |   2   |   7   |   3   |   8   |   4   |   9   |   5   |
| ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| INT1  |       | MOSI  |       | MISO  |       | SCLK  |       | 3.3V  |
|       |  CS   |       | INT2  |       | DRDY  |       |  GND  |       |

#    TODO

    [x] mirror 12-pin, notch down, flat pin 1 align as PMOD pin 1
