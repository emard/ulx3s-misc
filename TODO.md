# TODO

esp32

    [ ] SD card compatiblity sandisk
    [ ] sensor hotplug
    [ ] OBD2 support
    [ ] RTC support (for OBD without GPS)
    [ ] LCD display with freq and status
    [ ] LCD display IP address and hostname
    [ ] LCD graphic track display
    [ ] GPS time discontinuety warning
    [ ] TA flag at errors
    [ ] low free: erase oldest files, stop logging
    [ ] speech report remaining minutes and disk full
    [ ] get bytes free early to display when GPS is OFF
    [ ] fix wav file to open with wave.open("file.wav","r")
    [ ] >9.9 speak "out of scale"
    [ ] btn to stop logging
    [ ] web roaming, multiple ap/pass
    [ ] web upload reports "Error" although it's successful
    [ ] web server LED blink when activated and connected
    [ ] web server show SD free MB
    [ ] web server files to separate directory
    [ ] web MDNS not updating address to dnsmasq
    [ ] web server list dump only filenames not full path
    [x] web server show only filename, not full path
    [x] web server sort directories/files
    [x] EPS32 send to SPI speed, c/speed, report and tag iri
    [x] spoken report when sensors are missing
    [x] WiFi server
    [x] audio output to 3.5 mm jack
    [x] speech immediately at start logging
    [x] start/stop recording at speed hysteresis
    [x] sensor L/R status monitor and error reporting
    [x] RT display disk free
    [x] file named with timestamp
    [x] rename speech files to english filenames
    [x] 1-char 2^n MB free display 0-9
    [x] 1-char sensor status XLRY
    [x] test power lost during logging
    [x] config file for BT MAC, WiFi password and few parameters
    [x] tunnel mode: if signal is lost at > 40 km/h, assume same speed
    [x] CRC for IRI tags

core

    [ ] random inbalance in L/R calc results appears after stop or randomly
    [ ] handle delay from speed measurement to accelerometer reading
    [ ] simplify FM part, PCM is only 8-bit
    [ ] log sensor temperature
    [ ] core fm filter and downsample not working
    [ ] increase speech volume (compression?)
    [ ] time sync status
    [ ] BTN irq
    [x] slope should not reset at 0-speed
    [x] output register for trellis clean FM signal
    [x] improve audio quality with DACPWM
    [x] latch calc_result from changing while reading
    [x] dual frequency output 87.6 and 107.9
    [x] SPI slave for speed and iri

wav2kml

    [ ] csv dump
    [ ] snap https://automating-gis-processes.github.io/2017/lessons/L3/nearest-neighbour.html
    [ ] at stop cut the track and restart new
    [x] multiple input files
    [x] placemark every 100 m
    [x] lookat straight above
    [x] report speed range min/max to placemarks
