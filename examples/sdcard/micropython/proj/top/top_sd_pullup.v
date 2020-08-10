`default_nettype none
// write this to FPGA config flash
// and ESP32 should be able to mount
// SD card in 4-bit mode
module top_sd_pullup
(
  input  wire clk_25mhz,
  output wire [7:0] led,
  input  wire [6:0] btn,
  input  wire wifi_txd, ftdi_txd,
  output wire wifi_rxd, ftdi_rxd,
  input  wire sd_cmd, sd_clk,
  input  wire [3:0] sd_d
);
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;
  assign led = {sd_clk, sd_cmd, sd_d}; // must be used to enable pullups
endmodule
