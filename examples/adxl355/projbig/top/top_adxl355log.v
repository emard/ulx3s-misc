// passthru for ADXL355 accelerometer
// use with:
// adxl355.filter(0)
// adxl355.sync(6)
// adxl355.multird16()

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
module top_adxl355log
#(
  clk_out0_hz  = 40*1000000, // Hz, 40 MHz, PLL internal clock divisible by 512 to make 2*clk_adxl_hz=2048 kHz
  clk_adxl_hz  = 1024*1000,  // Hz, 1024 kHz, LUT-generated adxl clock
  clk_sync_hz  = 1000,       // Hz, 1 kHz SYNC clock, sample rate
  clk_sync_pulse_bits = 5,   // 2**(n-1)/2048kHz pulse width of SYNC clock minimal: 4->3.91us, reliable: 5->7.81us
  pa_sync_bits = 24          // SYNC phase accumulator bits
)
(
  input         clk_25mhz,
  input   [6:0] btn,
  output  [7:0] led,
  output        oled_csn, // LCD ST7789 backlight off
  //inout  [27:0] gp,gn,
  output        gp13, // ESP32   MISO
  output        gp14,gp15, // ADXL355 DRDY,INT2
  input         gp17, // ADXL355 INT1
  input         gn15, // ADXL355 MISO
  output        gn14,gn16,gn17, // ADXL355 SCLK,MOSI,CSn
  output        ftdi_rxd,
  input         ftdi_txd,
  output        wifi_rxd,
  input         wifi_txd,
  input         wifi_gpio0, wifi_gpio16, wifi_gpio17
);
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;

  wire int1 = gp17;
  wire int2; // gp15;
  wire drdy; // gp14;
  assign gp15 = int2;
  assign gp14 = drdy;

  wire csn, mosi, miso, sclk;

  // ADXL355 connections
  assign gn17 = csn;
  assign gn16 = mosi;
  assign miso = gn15;
  assign gn14 = sclk;

  // ESP32 connections
  assign csn  = wifi_gpio17;
  assign mosi = wifi_gpio16;
  assign gp13 = miso; // wifi_gpio35 v2.1.2
  assign sclk = wifi_gpio0;
  
  // base clock for making 1024 kHz for ADXL355
  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz(25*1000000),
    .out0_hz(clk_out0_hz)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks)
  );
  wire clk = clocks[0]; // 40 MHz system clock

  /*
  localparam divider1024kHz=clk_out0_hz*2/clk_adxl_hz; // default 78125 for half-period 2048 kHz from 40 MHz
  // the divider
  reg clk_sync; // 1.024kHz, must become 1 cca 25ns (1 clk cycle) before clk_adxl and keep 1 for at least 4 clk cycles
  reg clk_adxl; // 1024 kHz, toggle reg
  reg [$clog2(divider1024kHz)-1:0] clk_adxl_cnt; // divider counter for 1024 kHz
  reg [pa_sync_bits-1:0] pa_sync; // phase accumulator for sync signal
  localparam real re_pa_inc = 2.0 * clk_sync_hz * 2**pa_sync_bits / clk_adxl_hz; // default 32768 for 1kHz sample rate
  reg [pa_sync_bits-1:0] int_pa_inc = re_pa_inc; // sample rate frequency fine adjust reg implicit real->integer
  wire [pa_sync_bits:0] pa_sync_next = pa_sync + int_pa_inc; // one bit more for carry
  reg [clk_sync_pulse_bits-1:0] cnt_sync_fall;
  wire clk2048kHz = clk_adxl_cnt == divider1024kHz-1 ? 1 : 0;
  localparam clk_25ns_bits = 4;
  reg [clk_25ns_bits-1:0] clk_adxl_25ns; // 25ns step delay shift register
  reg [clk_25ns_bits-1:0] clk_sync_25ns; // 25ns step delay shift register
  always @(posedge clk)
  begin
    if(clk2048kHz) 
    begin // 2048 kHz execution
      clk_adxl_cnt <= 0;
      clk_adxl <= ~clk_adxl; // 1024 kHz toggle
      pa_sync <= pa_sync_next; // changes value 50 ns before clk_adxl edge
      if(pa_sync_next[pa_sync_bits]) // carry set
      begin // 1 kHz execution
        clk_sync <= 1; // changes value 25 ns before clk_adxl_cnt, required setup time
        cnt_sync_fall <= 0; // counts up to MSB set
      end
      else // counter to delay turn off
      begin
        if(cnt_sync_fall[clk_sync_pulse_bits-1]) // MSB set, minimum pulse width should be 4x 1024kHz cycles = 3.91us, count 8 should be 2x more than required
          clk_sync <= 0; // turn off clk_sync
        else
          cnt_sync_fall <= cnt_sync_fall+1;
      end
    end
    else
      clk_adxl_cnt <= clk_adxl_cnt+1;
    clk_adxl_25ns <= { clk_adxl_25ns[clk_25ns_bits-2:0], clk_adxl };
    clk_sync_25ns <= { clk_sync_25ns[clk_25ns_bits-2:0], clk_sync };
  end
  */

  adxl355_clk
  #(
    .clk_out0_hz(40*1000000), // Hz, 40 MHz, PLL internal clock divisible by 512 to make 2*clk_adxl_hz=2048 kHz
    .clk_pps_hz(1),           // Hz, 1 Hz, TODO not used
    .clk_adxl_hz(1024*1000),  // Hz, 1024 kHz, LUT-generated adxl clock
    .clk_sync_hz(1000)        // Hz, 1 kHz SYNC clock, sample rate
  )
  adxl355_clk_inst
  (
    .i_clk(clk),
    .i_pps(0),
    .o_clk_adxl(int2),
    .o_clk_sync(drdy)
  );

  // LED monitoring
  assign led[7:4] = {drdy,int2,int1,1'b0};
  //assign led[3:0] = {gn27,gn26,gn25,gn24};
  assign led[3:0] = {sclk,gp13,mosi,csn};
  //assign led[3:0] = {sclk,miso,mosi,csn};
  
  assign oled_csn = 0; // st7789 backlight off
  

endmodule
`default_nettype wire
