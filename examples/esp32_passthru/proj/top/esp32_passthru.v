// minimal passthru for ESP32 programming
// thanx to liebman

`default_nettype none
module esp32_passthru
#(
  // timeout to release SD lines after programing ESP32
  C_prog_release_timeout = 26 // default n=26, 2^n / 25MHz = 2.6s
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
  output       wifi_gpio0,
  //input        wifi_gpio5, // to enable pull down for programming
  inout  [3:0] sd_d, // wifi_gpio 13,12,4,2
  input        sd_cmd, sd_clk,
  output       sd_wp // BGA pin exists but not connected on PCB
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
  
  reg  [1:0] R_prog_in;
  wire [1:0] S_prog_in  = { ftdi_ndtr, ftdi_nrts };
  wire [1:0] S_prog_out = S_prog_in == 2'b10 ? 2'b01 
                        : S_prog_in == 2'b01 ? 2'b10 : 2'b11;
  //assign wifi_en = S_prog_out[1];
  assign wifi_en = S_prog_out[1] & ~btn[1]; // holding BTN1 disables ESP32, releasing BTN1 reboots ESP32
  assign wifi_gpio0 = S_prog_out[0];
  //assign wifi_gpio0 = S_prog_out[0] & btn[0]; // holding BTN0 will hold gpio0 LOW, signal for ESP32 to take control

  // detecting start of programming ESP32 and reset timeout
  reg [C_prog_release_timeout:0] R_prog_release;
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
  assign sd_wp = sd_clk | sd_cmd | /*wifi_gpio5*/ | sd_d; // force pullup for 4'hz above for listed inputs to make SD MMC mode work
  // sd_wp is not connected on PCB, just to prevent optimizer from removing pullups

  assign led[7] = 0;
  assign led[6] = S_prog_out[1]; // green LED ON = ESP32 enabled
  assign led[5] = ~R_prog_release[C_prog_release_timeout]; // orange LED ON = ESP32 programming
  assign led[4] = 0;
  assign led[3:0] = sd_d;

endmodule
`default_nettype wire
