# ADXL355 logger large project

# TODO

    [x] when reading 2-byte buffer pointer
        latch LSB byte when reading LSB for
        consistent 16-bit reading
    [x] write to SPI IO for tagging
    [x] write to SPI IO for audio message
    [ ] write to SPI IO for RDS display
    [ ] generate RDS message
    [ ] try to mount sandisk SD card
    [ ] SD card hotplug
    [ ] sensors hotplug
    [ ] stop logging below minimal speed (hysteresis 2-7 km/h)
    [ ] check NMEA crc
    [ ] parse NMEA to get time and date
    [ ] set system time and file names with creation time
    [ ] at low disk space, erase oldest data until 100 MB free
    [ ] more audio messages
    [ ] speak waiting for GPS signal
    [ ] speak saving data
    [ ] speak low battery
    [ ] speak no sensors (left, right)
    [ ] speak each 100 m
    [ ] speak raw measurement estimate
    [ ] speak erasing old data
