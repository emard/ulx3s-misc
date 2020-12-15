# DVI in (needs external GPDI PMOD)

External PMOD is required to capture DVI signal.
It has proper electrical termination and voltage offset
for differential inputs to work.

This example intention is to connect signal source (PC/RPI)
with standard cable to external GPDI PMOD connecter at ULX3S,
Connect normal monitor to ULX3S on onboard GPDI connector and
demonstrate that signal can be passed thru ULX3S.

DVI clock recovery is not automatic. User should
manually experiment with BTNs until proper picture appears.
BTNs dynamically change phase delay of PLL used for clock recovery.
Blue channel signal is most important, it contains sync signals.
No Blue - no picture. For Red and Green channels, wrong phase
is not critical, it will only make colors wrong, noisy or blurred.

DVI input is not possible with onboard GPDI connector.
FPGA lines to onboard connector are not differential input capable,
and even if they were, additional electrical interface
network or transciever chip would be needed to capture signal.

With onboard connector it is only possible to modify PCB
to test I2C EDID EEPROM emulation, so that external PC connected
recognizes it as DVI sink and starts generating picture signal.

For v3.0.x boards, a resistor of 0603 inch size, about 1k value,
(0.47k-2.2k) should be soldered parallel to C37. C37 is the capacitor
closest to DIP 4-switch, near GPDI connector on top side, with wrong
label C45 on PCB. It connects pin 19 of GPDI connector to FPGA line,
labeled gpdi_ethn aka gpdi_hpd.

For v3.1.x boards, don't solder, there is already resistor there.

Applying constant logical level 1 to HPD (Hot-Plug Detect) line will
make PC think it's a monitor connected, it will attempt to read I2C EDID
EEPROM for a list of supported video modes (currently 640x480@60Hz 25MHz
pixel clock) and start generating the picture signal.

On linux, "xrandr" command will show that second monitor is detected:

    $ xrandr
    Screen 0: minimum 16 x 16, current 2560 x 1200, maximum 32767 x 32767
    XWAYLAND0 connected 1920x1200+0+0 (normal left inverted right x axis y axis) 470mm x 300mm
       1920x1200     59.88*+
    XWAYLAND1 connected 640x480+1920+0 (normal left inverted right x axis y axis) 370mm x 300mm
       640x480       59.38*+
