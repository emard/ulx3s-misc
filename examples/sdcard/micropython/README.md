# micropython example SD card in 4-bit mode

For ESP32 to be able to use SD card in 4-bit mode
FPGA must pull up all SD card pins.
Compile and write to config flash:

    cd proj
    make flash

then ESP32 should be able to mount SD card in 4-bit mode (MMC mode)

    from machine import SDCard
    from os import mount, listdir
    mount(SDCard(),"/sd") # 4-bit mode
    #mount(SDCard(slot=3),"/sd") # 1-bit mode
    print(listdir("/sd"))

in esp32 directory there is small test bench for reading speed,
create some 1-10 MB "long_file.bin" on root of SD card, test will
read it:

    >>> import sdtest
    ['long_file.bin']
    1055 KB in 866 ms => 1218 KB/s
