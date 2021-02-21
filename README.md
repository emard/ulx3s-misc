# ESP32 Arduino to bluetooth GPS

10 Hz PPS clock recovery from bluetooth GPS NMEA
serial data. For recent 25 seconds it calculates average
difference (NMEA_day_time - millis_time), resolution +-4ms.
Then it phase locks 10 Hz PPS to millis+difference,
for difference more than 15 ms it applies 4x larger proportional
factor to lock phase, otherwise it will apply 4x smaller
proportional factor to reduce PPS jitter and have some hysteresys
when it is near lock.

ESP32 is bluetooth master (initiates connection)
and GPS is bluetooth device providing serial port.
Standard bluetooth serial is used (non-BLE).

For Garmin GLO usb-serial, firmware 2.60 should
be upgraded to 3.00.

For Garmin GLO firmware 2.60: If ESP32 is rebooted,
ESP32 connects to bluetooth serial but no serial traffic
appears with "Garmin GLO" GPS I have tested with firmware 2.60. 

The silent GPS also doesn't provide traffic to PC when it connects.
To restore traffic, GPS must be turned OFF and ON.
Firmware upgrade to 3.00 fixes it.
