# Collatz Conjecture test

This example searches for counterexample of Collatz Conjecture,
which may not exist.

HEX display (LCD/OLED and DVI) shows currently tested number.
DIP SW2 = OFF and BTN1 to single-step.
DIP SW2 = ON or hold BTN2 to continuousy explore numbers.
LED D0 will blink as numbers are explored.

If Collatz Conjecture counterexample number is found while
DIP SW2 is ON, blink will stop.
The number will be displayed on GPDI and ST7789 LCD.

