# ULX3S miscellaneous examples (advanced)

This is collection of miscellaneous examples for ULX3S.
Most examples are advanced and demonstrate various capabilites
of ULX3S board. Developed and tested on linux using commandline.

A novel structure of makefiles and scripts is used to ease and
the building and upload of the examples. All examples should
share same build scripts. Build scripts allow building of
the same example with diamond and trellins, to verify that
both produce mostly the same result or for a bug report if different :).

Opensource tools "prjtrellis", "nextpnr", "yosys" and "vhd2vl"
can be by default extracted to "/mt/scratch/tmp/openfpga/" and compiled.
Makefiles will use above path. This path can be changed at editing
"scripts/trellis_path.mk".

Installation of opensource tools using "make install" is not required.
