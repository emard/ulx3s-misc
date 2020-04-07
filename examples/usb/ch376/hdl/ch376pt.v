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
// BUSY D4 = GP[25]  A0  = GN[24] 1
// SCK  D5 = GP[24]  CS  = GN[23] 1
// MOSI D6 = GP[23]  RD  = GN[22] 0
// MISO D7 = GP[22]  WR  = GN[21] 0

// see https://github.com/djuseeq/Ch376msc

// enable CH376 SPI mode
// CH376 scans them only once - early at power-on time.
// This works at 25F with bitstream loaded from SPI FLASH.
// Bitstream uploaded over JTAG is too late, it won't enter
// SPI mode. In that case, hardwire WR=RD=GND CS=A0=+3.3V
// assign to 0/1 or use 1'bz as input and FPGA pull-down/pull-up

assign gp[21]   = 0; // CH376_WR;
assign gp[22]   = 0; // CH376_RD;
assign gp[23]   = 1; // CH376_CS;
assign gp[24]   = 1; // CH376_A0;

wire spi_csn, spi_clk, spi_mosi, spi_miso, spi_int, spi_busy;

assign gn[26]   = spi_csn;
assign gn[25]   = 1'bz;
assign spi_busy = gn[25];
assign gn[24]   = spi_clk;
assign gn[23]   = spi_mosi;
assign gn[22]   = 1'bz;
assign spi_miso = gn[22];
assign gn[25]   = 1'bz;
assign spi_int  = gp[25];

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
assign led[6]   = 0;
assign led[7]   = 0;
endmodule
