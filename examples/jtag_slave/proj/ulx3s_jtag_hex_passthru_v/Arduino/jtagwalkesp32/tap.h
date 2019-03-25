#ifndef TAP_H
#define TAP_H

#include "libxsvf.h"
#include <SPI.h>

#define TCK 14
#define TMS 15
#define TDI 13
#define TDO 12

extern SPIClass *spi_jtag;

static void tap_transition(struct libxsvf_host *h, int v);
int libxsvf_tap_walk(struct libxsvf_host *h, enum libxsvf_tap_state s);
#endif
