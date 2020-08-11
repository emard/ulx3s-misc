# micropython example SD card in 4-bit mode

For ESP32 (MicroPython v1.12 on 2019-12-20)
to be able to use SD card in 4-bit mode,
FPGA should pull up all SD card pins.
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

1-bit mode SDCard(slot=3):

    >>> import sdtest
    ['long_file.bin']
    1056 KB in 752 ms => 1404 KB/s file read
    4096 KB in 2746 ms => 1491 KB/s raw sector read

4-bit mode SDCard():

    >>> import sdtest
    ['long_file.bin']
    1056 KB in 492 ms => 2146 KB/s file read
    4096 KB in 1777 ms => 2305 KB/s raw sector read
