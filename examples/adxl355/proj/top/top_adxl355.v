// passthru for ADXL355 accelerometer

/*
https://wiki.analog.com/resources/eval/user-guides/eval-adicup360/hardware/adxl355
PMOD connected to GP,GN 14-17
Pin Number  Pin Function         Mnemonic  ULX3S
Pin 1       Chip Select          CS        GN17  LED0
Pin 2       Master Out Slave In  MOSI      GN16  LED1
Pin 3       Master In Slave Out  MISO      GN15  LED2
Pin 4       Serial Clock         SCLK      GN14  LED3
Pin 5       Digital Ground       DGND
Pin 6       Digital Power        VDD
Pin 7       Interrupt 1          INT1      GP17  LED4
Pin 8       Not Connected        NC        GP16
Pin 9       Interrupt 2          INT2      GP15  LED6
Pin 10      Data Ready           DRDY      GP14  LED7
Pin 11      Digital Ground       DGND
Pin 12      Digital Power        VDD
*/

`default_nettype none
module top_adxl355
(
  input         clk_25mhz,
  input   [6:0] btn,
  output  [7:0] led,
  inout  [27:0] gp,gn,
  input         gn15,
  //output        gp13, gn24, gn25, gn27,
  //input         gp24, gp26, gp27, gn26,
  output        ftdi_rxd,
  input         ftdi_txd,
  output        wifi_rxd,
  input         wifi_txd,
  input         wifi_gpio0, wifi_gpio16, wifi_gpio17
);
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;

  wire int1     = gp[17];
  wire int2     = gp[15];
  wire drdy     = gp[14];
  
  wire csn, mosi, miso, sclk;

  // ADXL355 connections
  assign gn[17] = csn;
  assign gn[16] = mosi;
  assign miso = gn15;
  assign gn[14] = sclk;

  // ESP32 connections
  assign csn  = wifi_gpio17;
  assign mosi = wifi_gpio16;
  assign gp[13] = miso; // wifi_gpio35 v2.1.2
  assign sclk = wifi_gpio0;

  // LED monitoring
  assign led[7:4] = {gp[14],gp[15],1'b0,gp[17]};
  //assign led[3:0] = {gn27,gn26,gn25,gn24};
  //assign led[3:0] = {sclk,gp13,mosi,csn};
  assign led[3:0] = {sclk,miso,mosi,csn};

endmodule
`default_nettype wire
