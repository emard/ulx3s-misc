// (c)EMARD
// License=BSD

// DB9 commodore/atari joystick adapter demo

module db9joy
(
input  wire gp14, gp15, gp16, gp17, gp18, gp19, gp20,
input  wire gn14, gn15, gn16, gn17, gn18, gn19, gn20,
output wire  [7:0] led,
input  wire  [6:0] btn,
input  wire  [0:3] sw,
output wire        ftdi_rxd,
input  wire        ftdi_txd,
output wire        wifi_rxd,
input  wire        wifi_txd
);

  // TX/RX passthru
  assign ftdi_rxd = wifi_txd;
  assign wifi_rxd = ftdi_txd;

  assign joy1_up         = gn14; // DB9 pin 1
  assign joy1_btn_left   = gp14; // DB9 pin 6
  assign joy1_down       = gn15; // DB9 pin 2
  assign joy1_left       = gp15; // DB9 pin 3
  assign joy1_right      = gn16; // DB9 pin 4
  assign joy1_btn_right  = gp16; // DB9 pin 9
  assign joy1_btn_middle = gn17; // DB9 pin 5

  assign joy2_up         = gp17; // DB9 pin 1
  assign joy2_btn_left   = gn18; // DB9 pin 6
  assign joy2_down       = gp18; // DB9 pin 2
  assign joy2_left       = gn19; // DB9 pin 3
  assign joy2_right      = gp19; // DB9 pin 4
  assign joy2_btn_right  = gn20; // DB9 pin 9
  assign joy2_btn_middle = gp20; // DB9 pin 5
  
  assign led[0] = ~joy2_left       | ~joy1_left       ;
  assign led[1] = ~joy2_right      | ~joy1_right      ;
  assign led[2] = ~joy2_up         | ~joy1_up         ;
  assign led[3] = ~joy2_down       | ~joy1_down       ;
  assign led[4] = ~joy2_btn_left   | ~joy1_btn_left   ;
  assign led[5] = ~joy2_btn_right  | ~joy1_btn_right  ;
  assign led[6] = ~joy2_btn_middle | ~joy1_btn_middle ;
  assign led[7] = ~joy2_left | ~joy2_right | ~joy2_up | ~joy2_down | ~joy2_btn_left | ~joy2_btn_right | ~joy2_btn_middle;

endmodule
