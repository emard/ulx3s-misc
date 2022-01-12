#!/bin/sh
#python3 ~/.arduino15/packages/esp32/tools/esptool_py/3.0.0/esptool.py
python ~/.arduino15/packages/esp32/tools/esptool_py/3.1.0/esptool.py \
  --chip esp32 --port /dev/ttyUSB0 --baud 921600 \
  --before default_reset --after hard_reset write_flash -z --flash_mode dio \
  --flash_freq 80m --flash_size detect \
  0xe000  boot_app0.bin@0xe000 \
  0x1000  bootloader_qio_80m.bin@0x1000 \
  0x10000 esp32btgps.ino.bin@0x10000 \
  0x8000  esp32btgps.ino.partitions.bin@0x8000 

# preferences [x] show detailed transfer
# python /home/davor/.arduino15/packages/esp32/tools/esptool_py/3.0.0/esptool.py
# --chip esp32 --port /dev/ttyUSB0 --baud 921600 --before default_reset --after hard_reset
# write_flash -z --flash_mode dio --flash_freq 80m --flash_size detect
# 0xe000 /home/davor/.arduino15/packages/esp32/hardware/esp32/1.0.6/tools/partitions/boot_app0.bin
# 0x1000 /home/davor/.arduino15/packages/esp32/hardware/esp32/1.0.6/tools/sdk/bin/bootloader_qio_80m.bin
# 0x10000 /tmp/arduino_build_86027/esp32btgps.ino.bin
# 0x8000 /tmp/arduino_build_86027/esp32btgps.ino.partitions.bin 
