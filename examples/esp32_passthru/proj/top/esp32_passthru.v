// minimal passthru for ESP32 programming
// thanx to liebman

`default_nettype none
module esp32_passthru (
  input  wire ftdi_txd,
  output wire ftdi_rxd,
  input  wire ftdi_ndtr,
  input  wire ftdi_nrts,
  input  wire wifi_txd,
  output wire wifi_rxd,
  output wire wifi_en,
  output wire wifi_gpio0
);
  // TX/RX passthru
  assign ftdi_rxd = wifi_txd;
  assign wifi_rxd = ftdi_txd;

  // Programming logic
  // SERIAL  ->  ESP32
  // DTR RTS -> EN IO0
  //  1   1     1   1
  //  0   0     1   1
  //  1   0     0   1
  //  0   1     1   0
  assign wifi_en    = ~ftdi_ndtr |  ftdi_nrts;
  assign wifi_gpio0 =  ftdi_ndtr | ~ftdi_nrts;

endmodule
`default_nettype wire
