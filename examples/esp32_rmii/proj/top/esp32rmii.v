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

  assign rmii_tx_en  = wifi_gpio21;
  assign rmii_tx0    = wifi_gpio19;
  assign rmii_tx1    = wifi_gpio22;
  assign wifi_gpio27 = rmii_crs;
  assign wifi_gpio25 = rmii_rx0;
  assign wifi_gpio26 = rmii_rx1;

  // protocol analyzer to generate 3-state control signal
  assign rmii_mdc   = wifi_gpio12; // wifi -> rmii, wifi generates MDC clock 2.5 MHz typical
  wire   wifi_mdio  = wifi_gpio4; // analyzer listens to wifi side
  reg [1:0] r_rmii_mdc; // MDC edge detection
  localparam c_rmii_mdio_bits = 32;
  reg [c_rmii_mdio_bits-1:0] r_rmii_mdio; // MDIO shift register
  localparam c_rmii_mdc_cnt_bits = 6;
  reg [c_rmii_mdc_cnt_bits-1:0] r_rmii_mdc_cnt = 0;
  reg [7:0] r_blink;
  reg mdio_read  = 0; // 3-state control signal
  //always @(posedge clk_25mhz)
  always @(posedge rmii_nint)
  begin
    r_rmii_mdc <= {rmii_mdc, r_rmii_mdc[1]};
    if(r_rmii_mdc == 2'b10) // rising edge
    begin
      r_rmii_mdio <= {r_rmii_mdio[c_rmii_mdio_bits-2:0], wifi_mdio};
      if(r_rmii_mdc_cnt[c_rmii_mdc_cnt_bits-1]) // read cycle finished
      begin // wait for new preamble and read cycle
        if(r_rmii_mdio[31:0] == 32'hFFFFFFF6)
        begin
          // read cycle detected, reset counter
          r_rmii_mdc_cnt <= 0;
          r_blink <= r_blink+1;
        end
      end
      else // read cycle active, increment
        r_rmii_mdc_cnt <= r_rmii_mdc_cnt + 1; // increment
    end
    mdio_read <= r_rmii_mdc_cnt == 11 ? 1 // begin 3-state read
               : r_rmii_mdc_cnt[c_rmii_mdc_cnt_bits-1] ? 0 // end   3-state read
               : mdio_read;               // no change
  end

  // normal
  assign gn13       = mdio_read ? 1'bz : wifi_gpio4; // wifi -> rmii
  assign wifi_gpio4 = mdio_read ? gn13 : 1'bz;       // rmii -> wifi

  // debug
  //wire read_test = r_rmii_mdc_cnt == 11 ? 1 : 0; // 11 -> 0x8000, 26 -> 0x0001
  //assign gn13 = 0;
  //assign wifi_gpio4 = mdio_read ? read_test : 1'bz;       // rmii -> wifi

  // TX/RX passthru
  assign ftdi_rxd = wifi_txd;
  assign wifi_rxd = ftdi_txd;

  // BTN1 -> reset and strapping timing

  reg [C_powerup_en_time:0] R_powerup_en_time = 1;
  generate
  if(C_powerup_en_time)
  always @(posedge clk_25mhz)
    R_powerup_en_time <= btn[1] ? 0 
                       : R_powerup_en_time[C_powerup_en_time] ? R_powerup_en_time
                       : R_powerup_en_time + 1; // increment until MSB=0
  endgenerate

  reg [C_powerup_strap_time:0] R_powerup_strap_time = 1;
  generate
  if(C_powerup_strap_time)
  always @(posedge clk_25mhz)
    R_powerup_strap_time <= btn[1] ? 0 
                          : R_powerup_strap_time[C_powerup_strap_time] ? R_powerup_strap_time
                          : R_powerup_strap_time + 1; // increment until MSB=0
  endgenerate

  assign wifi_en = R_powerup_en_time[C_powerup_en_time] ? 1 : 0;
  assign wifi_gpio0 = R_powerup_strap_time[C_powerup_strap_time] ? rmii_nint : 1;

/*
  assign led[7] = wifi_en;
  assign led[6] = ~R_powerup_en_time[C_powerup_en_time];
  assign led[5] = ~R_powerup_strap_time[C_powerup_strap_time];
  assign led[4] = 0;
  assign led[3] = wifi_gpio13;
  assign led[2] = wifi_gpio12;
  assign led[1] = wifi_gpio4;
  assign led[0] = wifi_gpio2;
*/
  assign led = r_blink;

endmodule
`default_nettype wire
