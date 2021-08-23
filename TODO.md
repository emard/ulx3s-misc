# TODO

esp32

    [ ] tunnel mode kml generate follow the same direction
    [ ] LCD display with freq and status
    [ ] LCD display IP address and hostname
    [ ] LCD graphic track display
    [ ] RTC support (for OBD without GPS)
    [ ] color scale config and description
    [ ] notify g-range in wav
    [ ] notify g-range in kml
    [ ] kml->kmz zip https://github.com/lbernstone/miniz-esp32
    [ ] kml handle missing sensors
    [ ] sensor hotplug
    [ ] script for binary exe upload to esp32 and fpga
    [ ] GPS time discontinuety bug warning
    [ ] TA flag at errors
    [ ] low free: erase oldest files, stop logging
    [ ] speech report when connected GPS/OBD
    [ ] speech report remaining minutes and disk full
    [ ] speech tunnel mode locked speed
    [ ] fix wav file to open with wave.open("file.wav","r")
    [ ] >9.9 speak "out of scale"
    [ ] btn to stop logging and close all files
    [ ] OBD2 stop PPS PLL
    [ ] web visited links in different color
    [ ] wep upload success readyState == 4, status == 200
    [ ] web server LED blink when activated and connected
    [ ] web MDNS not updating address to dnsmasq
    [ ] web server list dump only filenames not full path
    [x] web free using JSON var name for bytes free in dir listing
    [x] web server show only filename, not full path
    [x] web server sort directories/files
    [x] web server files to separate directory
    [x] web keep retrying to connect
    [x] web roaming, multiple ap/pass
    [x] web speak IP address
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
    [x] OBD2 support
    [x] OBD2 umount when BT lost
    [x] OBD2 stop count to lon degs
    [x] tag time and speed for OBD mode
    [x] BT connect GPS/OBD automatic
    [x] RDS display GPS/OBD mode
    [x] OBD2 time from saved last GPS location
    [x] OBD2 start from saved last GPS location
    [x] web upload reports "Error" although it's successful
    [x] get bytes free early to display when GPS is OFF
    [x] web show MB free
    [x] SD card compatiblity sandisk
    [x] web shorten time from power to BTN0 reading
    [x] web server bug eraseing HTML name when file in non-root directory is deleted
    [x] kml OBD mode bugs last latlon overwritten
    [x] kml generation
    [x] kml iterate old logs and finalize
    [x] web finalize before starting server
    [x] config log mode wav/kml
    [x] kml date in the document description
    [x] sensor range +-2-4-8 g configurable

core

    [ ] handle delay from speed measurement to accelerometer reading
    [ ] log sensor temperature
    [ ] increase speech volume (compression?)
    [ ] time sync status
    [ ] BTN irq
    [ ] tyre ribs or motor vibration (RPM) sensing, conversion to speed
    [x] damp oscillations at slope DC offset compensation
    [x] at stops, quick slope DC removal
    [x] improved slope DC removal
    [x] slope should not reset at 0-speed
    [x] output register for trellis clean FM signal
    [x] improve audio quality with DACPWM
    [x] latch calc_result from changing while reading
    [x] dual frequency output 87.6 and 107.9
    [x] SPI slave for speed and iri
    [x] random inbalance in L/R calc results (slope ready not used)

wav2kml

    [ ] csv dump
    [ ] on track and placemarks indicate tunnel mode
    [ ] motor vibration (RPM) sensing, conversion to speed
    [ ] calibrate accelerometer heading with GPS
    [ ] use accelerometer to determine heading in tunnel mode
    [x] at stop cut the track and restart new
    [x] multiple input files
    [x] placemark every 100 m
    [x] lookat straight above
    [x] report speed range min/max to placemarks
    [x] snap
    [x] colorized description
        https://developers.google.com/kml/documentation/kml_tut

math

    [ ] verify method - make the offline analysys

