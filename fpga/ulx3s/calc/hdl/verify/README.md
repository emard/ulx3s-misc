# VERIFICATION

Press cursor BTNs (BTN3-6) to set input slope
0x00000400 (1024 um/m) to both channels.

Run pyhton code, view it with cursor up-down, q to exit.

    ./verify-core-250mm.py | less

Press BTN1 for each step and verify that results
shown on LCD are exactly the same as in VZ (um/s)
hex output of the python code for slope 0x400:

    VZ=0xFFFFFF1C
    VZ=0xFFFFFD5B
    VZ=0xFFFFFBF2
    VZ=0xFFFFFB7A
    VZ=0xFFFFFBEC
    VZ=0xFFFFFCDE
    VZ=0xFFFFFDD2
    VZ=0xFFFFFE7D
    VZ=0xFFFFFECB
    VZ=0xFFFFFED9
    VZ=0xFFFFFED7
    VZ=0xFFFFFEE8
    VZ=0xFFFFFF1A
    VZ=0xFFFFFF66
    VZ=0xFFFFFFB8
    VZ=0x00000005
    VZ=0x00000043
    VZ=0x00000071
    ...

Negative slope values like 0xFFFF000 (-0x1000 in python)
also work, but for any given value, results may
slightly differ in last digit or two.
