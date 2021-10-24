# Collatz Conjecture test

This example searches for counterexample of Collatz Conjecture:

Collatz Conjecture states that starting with any positive
integer N and iterating:

    while N > 1:
      if (N & 1) == 0 then:
        N = N/2              # if N is even
      else:
        N = (3*N+1)/2        # if N is odd

In finite number of iterations, N should become 1.

As of 2020, it has been calculated by computers that
all numbers below 2^68 in finite number of iterations
become 1. Noone knows why nor has a proof for this.

This core implemepts abstract machine that
applies bit shift and addition to simplify

    3*N+1 = N+(2*N+1)

HEX display (LCD/OLED and DVI) shows currently tested number.

    DIP SW2 = OFF and BTN1 to single-step.
    DIP SW2 = ON or hold BTN2 to continuousy explore numbers.
    LED D0 will blink as numbers are explored.

If Collatz Conjecture counterexample number is found while
DIP SW2 is ON, blink will stop.
The number will be displayed on GPDI and ST7789 LCD.
