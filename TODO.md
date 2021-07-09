# TODO

esp32

    [ ] SD card compatiblity sandisk
    [ ] test power lost during logging
    [ ] web server files to separate directory
    [ ] config file for BT MAC, WiFi password and few parameters
    [ ] sensor hotplug
    [ ] OBD2 support
    [ ] LCD display with freq and status
    [ ] LCD display IP address and hostname
    [ ] GPS time discontinuty warning
    [ ] TA flag at errors
    [ ] low free: erase oldest files, stop logging
    [ ] speech report remaining minutes and disk full
    [x] estimate speed-accel integration value
    [ ] get bytes free early to display when GPS is OFF
    [ ] fix wav file to open with wave.open("file.wav","r")
    [x] EPS32 send to SPI speed, c/speed, report and tag iri
    [ ] >9.9 speak "out of scale"
    [ ] at 0-speed reset slope adjustment offset
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

core
    [ ] latch calc_result from changing while reading
    [ ] log sensor temperature
    [ ] core fm filter and downsample not working
    [ ] improve audio quality with DACPWM
    [x] dual frequency output 87.6 and 107.9
    [ ] increase speech volume
    [ ] time sync status
    [x] SPI slave for speed and iri

wav2kml
    [ ] placemark every 100 m
    [ ] snap
    [ ] at stop cut the track and restart new
    [x] report speed range min/max to placemarks
