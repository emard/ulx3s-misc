// passthru for ADXL355 accelerometer
// use with:
// adxl355.filter(0)
// adxl355.sync(2) # DRDY=SYNC input, internal oscillator
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
  clk_out0_hz  = 40*1000000, // Hz, 40 MHz, PLL generated internal clock
  pps_n        = 10,         // N, 1 Hz, number of PPS pulses per interval
  pps_s        = 1,          // s, 1 s, PPS interval
  clk_sync_hz  = 1000,       // Hz, 1 kHz SYNC pulse, sample rate
  pa_sync_bits = 30          // bit size of phase accumulator, less->faster convergence larger jitter , more->slower convergence less jitter
)
(
  input         clk_25mhz,
  input   [6:0] btn,
  output  [7:0] led,
  output        oled_csn, // LCD ST7789 backlight off
  output  [3:0] audio_l, audio_r,
  //inout  [27:0] gp,gn,
  output        gp13, // ESP32   MISO
  output        gp14, // ADXL355 DRDY
  input         gp15, // ADXL355 INT2
  input         gp17, // ADXL355 INT1
  input         gn15, // ADXL355 MISO
  output        gn14,gn16,gn17, // ADXL355 SCLK,MOSI,CSn
  input         gn11, // ESP32 wifi_gpio26 PPS to FPGA
  output        gp11, // ESP32 wifi_gpio26 PPS feedback
  input         ftdi_nrts,
  input         ftdi_ndtr,
  output        ftdi_rxd,
  input         ftdi_txd,
  output        wifi_en,
  output        wifi_rxd,
  input         wifi_txd,
  input         wifi_gpio5,
  output        wifi_gpio0, 
  input         wifi_gpio16, wifi_gpio17
);
  // usb-serial console
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;
  // programming esp32
  assign wifi_en    = ~ftdi_ndtr |  ftdi_nrts;
  assign wifi_gpio0 =  ftdi_ndtr | ~ftdi_nrts;
  // todo make wifi_gpio0 bidirectional when not programming
  // so esp32-spi -> fpga-adxl is possible

  wire int1 = gp17;
  wire int2 = gp15;
  wire drdy; // gp14;
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

  // generate PPS signal (1 Hz, 100 ms duty cycle)
  localparam pps_cnt_max = clk_out0_hz*pps_s/pps_n; // cca +-20000 tolerance
  localparam pps_width   = pps_cnt_max/10;   
  reg [$clog2(pps_cnt_max)-1:0] pps_cnt;
  reg pps;
  always @(posedge clk)
  begin
    if(pps_cnt == pps_cnt_max-1)
      pps_cnt <= 0;
    else
      pps_cnt <= pps_cnt+1;
    if(pps_cnt == 0)
      pps <= 1;
    else if(pps_cnt == pps_width-1)
      pps <= 0;
  end
  
  assign wifi_gpio25 = gn11;
  assign gp11 = wifi_gpio26;

  //wire pps_btn = pps & ~btn[1];
  //wire pps_btn = wifi_gpio5 & ~btn[1];
  wire pps_btn = wifi_gpio25 & ~btn[1];
  //wire pps_btn = ftdi_nrts & ~btn[1];
  wire pps_feedback;
  assign wifi_gpio26 = pps_feedback;
  assign pps_feedback = pps_btn; // ESP32 needs its own PPS feedback

  wire [7:0] phase;
  wire pps_valid, sync_locked;
  adxl355_sync
  #(
    .clk_out0_hz(clk_out0_hz), // Hz, 40 MHz, PLL internal clock
    .pps_n(pps_n),             // N, 1 Hz when pps_s=1
    .pps_s(pps_s),             // s, 1 s PPS interval
    .pps_tol_us(500),          // us, 500 us, default +- tolerance for pulse rising edge
    .clk_sync_hz(clk_sync_hz), // Hz, 1 kHz SYNC clock, sample rate
    .pa_sync_bits(pa_sync_bits)// PA bit size
  )
  adxl355_clk_inst
  (
    .i_clk(clk),
    .i_pps(pps_btn), // rising edge sensitive
    .i_faster(btn[6]),
    .i_slower(btn[5]),
    .o_cnt(phase), // monitor phase angle
    .o_pps_valid(pps_valid),
    .o_locked(sync_locked),
    .o_clk_sync(drdy)
  );
  
  // sync counter
  reg [11:0] cnt_sync, cnt_sync_prev;
  reg [1:0] sync_shift, pps_shift;
  always @(posedge clk)
  begin
    pps_shift <= {pps_btn, pps_shift[1]};
    if(pps_shift == 2'b10) // rising
    begin
      cnt_sync_prev <= cnt_sync;
      cnt_sync <= 0;
    end
    else
    begin
      sync_shift <= {drdy, sync_shift[1]};
      if(sync_shift == 2'b01) // falling to avoid sampling near edge
      begin
        cnt_sync <= cnt_sync+1;
      end
    end
  end

  // LED monitoring

  //assign led[7:4] = {drdy,int2,int1,1'b0};
  //assign led[3:0] = {gn27,gn26,gn25,gn24};
  //assign led[3:0] = {sclk,gp13,mosi,csn};
  //assign led[3:0] = {sclk,miso,mosi,csn};

  assign led[7:4] = phase[7:4];
  assign led[3] = 0;
  assign led[2] = sync_locked;
  assign led[1] = pps_valid;
  assign led[0] = pps_btn;

  //assign led = phase;
  //assign led = cnt_sync_prev[7:0]; // should show 0xE8 from 1000 = 0x3E8
  
  assign audio_l[3:1] = 0;
  assign audio_l[0] = drdy;
  assign audio_r[3:1] = 0;
  assign audio_r[0] = pps_btn;

  assign oled_csn = 0; // st7789 backlight off

endmodule
`default_nettype wire
