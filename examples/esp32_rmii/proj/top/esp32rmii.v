// minimal passthru for ESP32 programming
// thanx to liebman

`default_nettype none
module esp32rmii
#(
  // time to hold EN down after power up,
  // 0 to disable
  // 9 or more to reset ESP32 at power up
  //   (for boards where ESP32 doesn't boot at power up)
  //   wifi_gpio0-15k-3.3V pullup missing
  C_powerup_en_time = 10,
  C_powerup_strap_time = 20
  // timeout to release SD lines after programing ESP32
)
(
  input        clk_25mhz,
  input  [6:0] btn,
  output [7:0] led,
  input        ftdi_txd,
  output       ftdi_rxd,
  input        ftdi_ndtr,
  input        ftdi_nrts,
  input        wifi_txd,
  output       wifi_rxd,
  output       wifi_en,
  inout        wifi_gpio4,
  input        wifi_gpio12,
  input        wifi_gpio19, wifi_gpio21, wifi_gpio22,
  output       wifi_gpio0,  wifi_gpio25, wifi_gpio26, wifi_gpio27,
  input        gp11, gp12,
  input        gn11, gn12,
  inout        gn13,
  output       gp13,
  output            gp10,
  output       gn9, gn10,
  //inout [27:0] gp,gn,
  //inout  [3:0] sd_d, // wifi_gpio 13,12,4,2
  //input        sd_cmd, sd_clk,
  output       sd_wp // BGA pin exists but not connected on PCB
);
  // ETH RMII LAN8720 signals labelled on the PCB
  wire rmii_tx_en ; assign gn10 = rmii_tx_en; // 0:RX 1:TX
  wire rmii_tx0   ; assign gp10 = rmii_tx0;
  wire rmii_tx1   ; assign gn9  = rmii_tx1;
  wire rmii_crs   =        gp12; // 0:IDLE 1:RX DATA VALID
  wire rmii_rx0   =        gn11;
  wire rmii_rx1   =        gp11;
  wire rmii_nint  =        gn12; // clock 50MHz
  //wire rmii_mdio  =        gn13; // bidirectional
  wire rmii_mdc   ; assign gp13 = rmii_mdc;

  // GPIO00 - EMAC_TX_CLK : nINT/REFCLK (50MHz)
  // GPIO12 - SMI_MDC     : MDC  (relocateable)
  // GPIO04 - SMI_MDIO    : MDIO (relocateable)
  // GPIO19 - EMAC_TXD0   : TX0
  // GPIO21 - EMAC_TX_EN  : TX_EN
  // GPIO22 - EMAC_TXD1   : TX1
  // GPIO25 - EMAC_RXD0   : RX0
  // GPIO26 - EMAC_RXD1   : RX1
  // GPIO27 - EMAC_RX_DV  : CRS

  // assign wifi_gpio0  = rmii_nint; // GPIO00 - EMAC_TX_CLK : nINT/REFCLK (50MHz)

  assign rmii_tx_en  = wifi_gpio21;
  assign rmii_tx0    = wifi_gpio19;
  assign rmii_tx1    = wifi_gpio22;
  assign wifi_gpio27 = rmii_crs;
  assign wifi_gpio25 = rmii_rx0;
  assign wifi_gpio26 = rmii_rx1;

  assign rmii_mdc   = wifi_gpio12; // wifi generates MDC clock 2.5 MHz typical
  // TODO protocol analyzer to generate 3-state signal
  wire   mdio_read  = 0;
  assign gn13       = mdio_read ? 1'bz : wifi_gpio4; // wifi -> rmii
  assign wifi_gpio4 = mdio_read ? gn13 : 1'bz;       // rmii -> wifi
  wire   wifi_mdio  = wifi_gpio4; // analyzer listens to wifi side

  reg [1:0] r_rmii_mdc; // edge detection
  always @(posedge clk_25mhz)
    r_rmii_mdc <= {rmii_mdc, r_rmii_mdc[1]};
  reg [15:0] r_blink;
  always @(posedge clk_25mhz)
  begin
    if(r_rmii_mdc == 2'b10) // rising edge
      r_blink <= r_blink+1;
  end

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

/*
  reg  [1:0] R_prog_in;
  wire [1:0] S_prog_in  = { ftdi_ndtr, ftdi_nrts };
  wire [1:0] S_prog_out = S_prog_in == 2'b10 ? 2'b01 
                        : S_prog_in == 2'b01 ? 2'b10 : 2'b11;
*/
  reg [C_powerup_en_time:0] R_powerup_en_time = 1;
  generate
  if(C_powerup_en_time)
  always @(posedge clk_25mhz)
  begin
    if(R_powerup_en_time[C_powerup_en_time] == 1'b0)
      R_powerup_en_time <= R_powerup_en_time + 1; // increment until MSB=0
  end
  endgenerate

  reg [C_powerup_strap_time:0] R_powerup_strap_time = 1;
  generate
  if(C_powerup_strap_time)
  always @(posedge clk_25mhz)
  begin
    if(R_powerup_strap_time[C_powerup_strap_time] == 1'b0)
      R_powerup_strap_time <= R_powerup_strap_time + 1; // increment until MSB=0
  end
  endgenerate

  assign wifi_en = R_powerup_en_time[C_powerup_en_time] & ~btn[1]; // holding BTN1 disables ESP32, releasing BTN1 reboots ESP32
  assign wifi_gpio0 = R_powerup_strap_time[C_powerup_strap_time] ? rmii_nint : 1;

/*
  //assign wifi_en = S_prog_out[1];
  assign wifi_en = S_prog_out[1] & R_powerup_en_time[C_powerup_en_time] & ~btn[1]; // holding BTN1 disables ESP32, releasing BTN1 reboots ESP32
  assign wifi_gpio0 = R_powerup_en_time[C_powerup_en_time] ? rmii_nint : S_prog_out[0];
  //assign wifi_gpio0 = S_prog_out[0] & btn[0]; // holding BTN0 will hold gpio0 LOW, signal for ESP32 to take control

  // detecting start of programming ESP32 and reset timeout
  reg [C_prog_release_timeout:0] R_prog_release = -1;
  always @(posedge clk_25mhz)
  begin
    R_prog_in <= S_prog_in;
    if(R_prog_in != 2'b10 && S_prog_in == 2'b10)
      R_prog_release <= 0; // keep resetting during start of ESP32 programming
    else
      if(R_prog_release[C_prog_release_timeout] == 1'b0)
        R_prog_release <= R_prog_release + 1; // increment until MSB=0
  end
  // wifi_gpio2 for programming must go together with wifi_gpio0
  // wifi_gpio12 (must be 0 for esp32-wrover fuse unprogrammed, maybe 1 for esp32-wroom)
  assign sd_d  = R_prog_release[C_prog_release_timeout] ? 4'hz : { 3'b101, S_prog_out[0] }; // wifi_gpio 13,12,4,2
  assign sd_wp = sd_clk | sd_cmd | sd_d; // force pullup for 4'hz above for listed inputs to make SD MMC mode work
  // sd_wp is not connected on PCB, just to prevent optimizer from removing pullups
*/

  assign led[7] = wifi_en;
  assign led[6] = ~R_powerup_en_time[C_powerup_en_time];
  assign led[5] = ~R_powerup_strap_time[C_powerup_strap_time];
  assign led[4] = 0;
  assign led[3] = wifi_gpio13;
  assign led[2] = wifi_gpio12;
  assign led[1] = wifi_gpio4;
  assign led[0] = wifi_gpio2;

  //assign led = r_blink[14:7];

endmodule
`default_nettype wire
