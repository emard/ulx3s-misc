`default_nettype none

// define none or one of:
//`define i2c_bridge_v20
//`define i2c_bridge_v316

module top_esp32_passthru
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
  // timeout to release SD lines after programing ESP32
  parameter C_prog_release_timeout = 26 // default n=26, 2^n / 25MHz = 2.6s
)
(
  // Clock
  input  wire clk_25mhz,

  // LEDs
  output wire [7:0] led,

  // Buttons
  input  wire [6:0] btn,
	
  // ESP32 passthru UART
  input  wire ftdi_txd,
  output wire ftdi_rxd,
  input  wire ftdi_ndtr,
  input  wire ftdi_nrts,

  // ESP32 passthru
  input  wire wifi_txd,
  output wire wifi_rxd,
  input  wire wifi_gpio15, wifi_gpio14,
  inout  wire wifi_gpio13, wifi_gpio12,
  inout  wire wifi_gpio4 , wifi_gpio2 , wifi_gpio0 ,
  inout  wire wifi_en,
  output wire sd_wp, // BGA pin exists but not connected on PCB

  // ESP32 i2c bridge
  `ifdef i2c_bridge_v20    // ULX3S v2.x.x or v3.0.x
  inout  wire wifi_gpio16, // i2c sda ESP32 v3.0.x
  inout  wire wifi_gpio17, // i2c scl ESP32 v3.0.x
  inout  wire gpdi_sda,    // i2c sda RTC and GPDI
  inout  wire gpdi_scl,    // i2c scl RTC and GPDI
  `endif
  `ifdef i2c_bridge_v316   // ULX3S v3.1.x
  inout  wire wifi_gpio22, // i2c sda ESP32 v3.1.7
  inout  wire wifi_gpio21, // i2c scl ESP32 v3.1.7
  inout  wire gpdi_sda,    // i2c sda RTC and GPDI
  inout  wire gpdi_scl,    // i2c scl RTC and GPDI
  `endif

  // SPI Flash
  //inout  wire flash_mosi,
  //inout  wire flash_miso,
  inout  wire flash_wpn,
  inout  wire flash_holdn,
  //inout  wire flash_csn,

  // Boot
  inout  wire user_programn
);

  esp32_passthru
  #(
    .C_progndelay(C_progndelay), // 16: normal
    .C_powerup_en_time(C_powerup_en_time), // 0: normal, 10: v3.1.6 workaround but then uftpd will have problems
    .C_prog_release_timeout(C_prog_release_timeout) // 26: normal
  )
  esp32_passthru_inst
  (
    .clk_25mhz(clk_25mhz),
    .btn(btn),
    .led(led),
    .ftdi_txd(ftdi_txd),
    .ftdi_rxd(ftdi_rxd),
    .ftdi_ndtr(ftdi_ndtr),
    .ftdi_nrts(ftdi_nrts),
    .wifi_txd(wifi_txd),
    .wifi_rxd(wifi_rxd),
    .wifi_gpio15(wifi_gpio15),
    .wifi_gpio14(wifi_gpio14),
    .wifi_gpio13(wifi_gpio13),
    .wifi_gpio12(wifi_gpio12),
    .wifi_gpio4(wifi_gpio4),
    .wifi_gpio2(wifi_gpio2),
    .wifi_gpio0(wifi_gpio0),
    .wifi_en(wifi_en),
    `ifdef i2c_bridge_v20
    .wifi_sda(wifi_gpio16),
    .wifi_scl(wifi_gpio17),
    .gpdi_sda(gpdi_sda),    // c2c board GPDI and RTC
    .gpdi_scl(gpdi_scl),    // i2c board GPDI and RTC
    `endif
    `ifdef i2c_bridge_v316
    .wifi_sda(wifi_gpio22),
    .wifi_scl(wifi_gpio21),
    .gpdi_sda(gpdi_sda),    // i2c board GPDI and RTC
    .gpdi_scl(gpdi_scl),    // i2c board GPDI and RTC
    `endif
    .user_programn(user_programn),
    .nc(sd_wp) // BGA pin exists but not connected on PCB
  );

  // This helps for JTAG-FLASH.
  // Some boards with IS25LP128 FLASH need this.
  // Without this, flash chip returns only FF.
  // Prevents crosstalk to wpn and holdn:
  assign flash_wpn   = 1;
  assign flash_holdn = 1;

endmodule
