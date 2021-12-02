// minimal passthru for ESP32 programming
// thanx to liebman

`default_nettype none
module esp32_passthru
#(
  // BTN0 delay PROGRAMN prevents exit immediately
  parameter C_progndelay = 16, // 2^n clocks
  // time to hold EN down after power up,
  // 0 to disable (normal)
  // 9 or more to reset ESP32 at power up
  //   (for boards where ESP32 doesn't boot at power up)
  //   wifi_gpio0-15k-3.3V pullup missing
  //   issues uftpd: ESP32 will reset after upload
  //   so flash from uftpd will not return properly
  parameter C_powerup_en_time = 0,
  // glitch preventer, preventes unwanted wifi_en glitch because of BTN2 used
  parameter C_wifi_en_time = 9,
  // timeout to release SD lines after programing ESP32
  parameter C_prog_release_timeout = 26 // default n=26, 2^n / 25MHz = 2.6s
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
  input        wifi_gpio15, wifi_gpio14,
  inout        wifi_gpio13, wifi_gpio12,
               wifi_gpio4 , wifi_gpio2 , wifi_gpio0 ,
  inout        wifi_en,
  //inout        wifi_gpio5 // v3.0.x, not available on v3.1.x
  inout        wifi_sda, wifi_scl, // I2C ESP32
  inout        gpdi_sda, gpdi_scl, // I2C BOARD
  inout        user_programn, // to exit this bitstream
  output       nc // BGA pin exists but not connected on PCB
);
  // TX/RX passthru
  assign ftdi_rxd = wifi_txd;
  assign wifi_rxd = ftdi_txd;
  
  // debug serial loopback (if ESP32 won't program, disable above and check this)
  //assign ftdi_rxd = ftdi_txd;

  // Programming logic
  // SERIAL  ->  ESP32
  // DTR RTS -> EN IO0
  //  1   1     1   1
  //  0   0     1   1
  //  1   0     0   1
  //  0   1     1   0
  
  reg  [1:0] R_prog_in;
  wire [1:0] S_prog_in  = { ftdi_ndtr, ftdi_nrts };
  wire [1:0] S_prog_out = S_prog_in == 2'b10 ? 2'b01 
                        : S_prog_in == 2'b01 ? 2'b10 : 2'b11;
  reg [C_powerup_en_time:0] R_powerup_en_time = 1;
  generate
  if(C_powerup_en_time)
  always @(posedge clk_25mhz)
  begin
    if(R_powerup_en_time[C_powerup_en_time] == 1'b0)
      R_powerup_en_time <= R_powerup_en_time + 1; // increment until MSB=0
  end
  endgenerate

  reg [C_wifi_en_time:0] R_wifi_en_time = 1;
  generate
  if(C_wifi_en_time)
  always @(posedge clk_25mhz)
  begin
    if(R_wifi_en_time[C_wifi_en_time] == 1'b0)
      R_wifi_en_time <= R_wifi_en_time + 1; // increment until MSB=0
  end
  endgenerate

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
  // wifi_gpio12 (must be 0 for esp32-wroom fuse unprogrammed. esp32-wrover-e works for 0 and 1)

  assign wifi_en      = S_prog_out[1] & R_powerup_en_time[C_powerup_en_time] & ~(btn[2] & R_wifi_en_time[C_wifi_en_time]) ? 1'bz : 1'b0;
  assign wifi_gpio13  = R_prog_release[C_prog_release_timeout] ? 1'bz : 1'b1;
  assign wifi_gpio12  = R_prog_release[C_prog_release_timeout] ? 1'bz : 1'b0;
  //assign wifi_gpio12  = btn[3]; // experiment with ESP32 VRef 3.3V/1.8V
  //assign wifi_gpio5   = R_prog_release[C_prog_release_timeout] ? 1'bz : 1'b0; // available on v3.0.x only
  assign wifi_gpio4   = R_prog_release[C_prog_release_timeout] ? 1'bz : 1'b1;
  assign wifi_gpio2   = R_prog_release[C_prog_release_timeout] ? 1'bz : S_prog_out[0];
  assign wifi_gpio0   = R_prog_release[C_prog_release_timeout] ? 1'bz : S_prog_out[0];
  //assign wifi_gpio0 = S_prog_out[0] & btn[0]; // holding BTN0 will hold gpio0 LOW, signal for ESP32 to take control

  assign nc    = wifi_en     | wifi_gpio0  /* | wifi_gpio5 */ // bootstrapping pins pullups
               | wifi_gpio15 | wifi_gpio14 | wifi_gpio13 | wifi_gpio12 | wifi_gpio4 | wifi_gpio2; // bootstrapping and force pullup sd_cmd, sd_clk, sd_d[3:0] to make SD MMC mode work
  // nc is not connected on PCB, just to prevent optimizer from removing pullups

  // i2c bridge for ESP32 to access onboard RTC

  // slow clock enable pulse 5 MHz
  localparam bridge_clk_div = 3; // div = 1+2^n, 25/(1+2^2)=5 MHz
  reg [bridge_clk_div:0] bridge_cnt;
  always @(posedge clk_25mhz) // 25 MHz
  begin
    if(bridge_cnt[bridge_clk_div])
      bridge_cnt <= 0;
    else
      bridge_cnt <= bridge_cnt + 1;
  end
  wire clk_bridge_en = bridge_cnt[bridge_clk_div];

  wire [1:0] i2c_sda_i = {gpdi_sda, wifi_sda};
  wire [1:0] i2c_sda_t;
  i2c_bridge i2c_sda_bridge_i
  (
    .clk(clk_25mhz),
    .clk_en(clk_bridge_en),
    .i(i2c_sda_i),
    .t(i2c_sda_t)
  );
  assign gpdi_sda = i2c_sda_t[1] ? 1'bz : 1'b0;
  assign wifi_sda = i2c_sda_t[0] ? 1'bz : 1'b0;

  wire [1:0] i2c_scl_i = {gpdi_scl, wifi_scl};
  wire [1:0] i2c_scl_t;
  i2c_bridge i2c_scl_bridge_i
  (
    .clk(clk_25mhz),
    .clk_en(clk_bridge_en),
    .i(i2c_scl_i),
    .t(i2c_scl_t)
  );
  assign gpdi_scl = i2c_scl_t[1] ? 1'bz : 1'b0;
  assign wifi_scl = i2c_scl_t[0] ? 1'bz : 1'b0;

  // BTN0 exit this bitstream
  // delay prevents immediate exit
  reg [C_progndelay:0] delay_programn = 0;
  always @(posedge clk_25mhz)
    delay_programn <= btn[0] ? 0 : delay_programn+1;
  assign user_programn = delay_programn[C_progndelay] ? 1'b0 : 1'bz;

  // LED diagnostics

  assign led[7] = wifi_en;      // blue
  //assign led[6] = ~R_prog_release[C_prog_release_timeout]; // green LED ON = ESP32 programming
  assign led[6] = wifi_gpio15;  // green
  assign led[5] = wifi_gpio14;  // orange
  assign led[4] = wifi_gpio13;  // red
  assign led[3] = wifi_gpio12;  // blue   only this LED should be OFF by default
  assign led[2] = wifi_gpio4;   // green
  assign led[1] = wifi_gpio2;   // orange
  assign led[0] = wifi_gpio0;   // red

endmodule
`default_nettype wire
