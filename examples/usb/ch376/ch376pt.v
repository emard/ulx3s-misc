// AUTHOR=EMARD
// LICENSE=BSD

// CH376 passthru core to ESP32 (untested)

module ch376pt
(
    input   clk_25mhz,
    input   [6:0] btn,
    output  [7:0] led,
    inout   [27:0] gp, gn,
    input   ftdi_txd,
    output  ftdi_rxd,
    inout   [3:0] sd_d,
    inout   sd_clk, sd_cmd,
    input   wifi_txd,
    output  wifi_rxd,
    inout   wifi_gpio5, wifi_gpio16, wifi_gpio17,
    output  wifi_gpio0
);

// serial passthru to ESP32 (micropython prompt should work)
assign wifi_rxd = ftdi_txd;
assign ftdi_rxd = wifi_txd;

// CH376 module jumper "P_S" should connect "_" and "S"
// flat cable crimped pinout (plugged to male pins up on ULX3S)
// if male pins down, or female 90° then swap GP/GN
// D0 = GN[27]  GND = GND
// D1 = GP[27]  GND = GND
// D2 = GN[26]  VCC = +5V
// D3 = GP[26]  INT = GN[25]
// D4 = GP[25]  AO  = GN[24]
// D5 = GP[24]  CS  = GN[23]
// D6 = GP[23]  RD  = GN[22]
// D7 = GP[22]  WR  = GN[21]

// see https://github.com/djuseeq/Ch376msc

// enable CH376 SPI mode
assign GN[21]   = 0; // CH376_WR;
assign GN[22]   = 0; // CH376_RD;
assign GN[23]   = 1; // CH376_CS;

wire spi_csn, spi_clk, spi_mosi, spi_miso, spi_int;

assign GP[26]   = spi_csn;
assign GP[24]   = spi_clk;
assign GP[23]   = spi_mosi;
assign spi_miso = GP[22];
assign spi_int  = GN[25];

assign spi_csn  = ~wifi_gpio5;
assign spi_clk  =  wifi_gpio16;
assign spi_mosi =  sd_d[1];  // wifi_gpio4
assign sd_d[2]  =  spi_miso; // wifi_gpio12 

endmodule
