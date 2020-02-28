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
//      D0 = GN[27]  GND = GND
//      D1 = GP[27]  GND = GND
//      D2 = GN[26]  VCC = +5V
// CSN  D3 = GP[26]  INT = GN[25]
// BUSY D4 = GP[25]  AO  = GN[24]
// SCK  D5 = GP[24]  CS  = GN[23] 1
// MOSI D6 = GP[23]  RD  = GN[22] 0
// MISO D7 = GP[22]  WR  = GN[21] 0

// see https://github.com/djuseeq/Ch376msc

// enable CH376 SPI mode (this GN doesn't actually work)
// SPI setting pins have to be hardwired because
// CH376 scans them only once - early at power-on time.
// When bitstream is loaded, it will set those pins too late,
// at that time CH376 has already booted to parallel (not SPI) mode.
assign gn[21]   = 0; // CH376_WR;
assign gn[22]   = 0; // CH376_RD;
assign gn[23]   = 1; // CH376_CS;

wire spi_csn, spi_clk, spi_mosi, spi_miso, spi_int, spi_busy;

assign gp[26]   = spi_csn;
assign gp[25]   = 1'bz;
assign spi_busy = gp[25];
assign gp[24]   = spi_clk;
assign gp[23]   = spi_mosi;
assign gp[22]   = 1'bz;
assign spi_miso = gp[22];
assign gp[25]   = 1'bz;
assign spi_int  = gn[25];

assign spi_csn  = ~wifi_gpio5;
assign spi_clk  =  wifi_gpio16;
assign wifi_gpio0 = spi_busy;

assign sd_d[3]  = 1'bz;
assign sd_d[2]  = spi_miso & btn[0]; // MISO wifi_gpio12
assign sd_d[1]  = 1'bz;
assign spi_mosi = sd_d[1] & btn[0]; // MOSI wifi_gpio4
assign sd_d[0]  = 1'bz;


assign led[0]   = spi_csn;
assign led[1]   = spi_clk;
assign led[2]   = spi_miso;
assign led[3]   = spi_mosi;
assign led[4]   = spi_int;
assign led[5]   = spi_busy;

assign led[7:6] = 0;
endmodule
