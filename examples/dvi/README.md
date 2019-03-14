# Project Trellis DVI

Simple VGA video example
from [fpga4fun](https://www.fpga4fun.com/HDMI.html) shows
color test picture on DVI monitor.
VGA video signal (8-bit RGB, hsync, vsync, blank)
is converted to 10-bit digital video, serialized with DDR/SDR option,
and sent to single-ended otputs as fake differential signal.
It works on ULX3S with latest prjtrellis.

For prjtrellis, compile it with:

    make 

Same source can also be compiled with Lattice Diamond:

    make -f makefile.diamond

A part of diamond closed-source tools (DDTCMD) is used here to create
*.vme programming file for "FleaFPGA-JTAG" tool, but it can be skiped as
generated *.bin file can be programmed and flashed with our "ujprog" tool
and generated *.svf file can be programmed with latest "openocd" or uploaded
remotely using onboard ESP32 WiFi.

# Compiling the opensource tools

get prjtrellis (it should autmatically pull its latest database) and compile

    git clone https://github.com/SymbiFlow/prjtrellis
    cd prjtrellis/libtrellis
    cmake -DCMAKE_INSTALL_PREFIX=/usr .
    make

get yosys, and compile

    git clone https://github.com/YosysHQ/yosys
    cd yosys
    make config-gcc
    make 

get fresh nextpnr

    git clone https://github.com/YosysHQ/nextpnr
    cd nextpnr
    cmake -DARCH=ecp5 -DTRELLIS_ROOT=/path/to/prjtrellis .
    make

In case of some errors, delete "CMakeCache.txt", change something like
quoting last arg in file "CMakeLists.txt" around line 123:

    -    STRING(REGEX REPLACE "[^0-9]" "" boost_py_version ${version})
    +    STRING(REGEX REPLACE "[^0-9]" "" boost_py_version "${version}")

If some older python file is missing, as a quick'n'drty fix just symlink
to the newer file that's currently installed:

    cd /usr/lib/x86_64-linux-gnu
    ln -s libpython3.7m.so libpython3.6m.so

To force-recompile existing nextpnr with newer prjtrellis database:

    cd nextpnr
    touch ecp5/trellis_import.py
    make clean
    make
