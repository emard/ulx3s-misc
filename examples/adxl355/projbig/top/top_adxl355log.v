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

PMOD connected to GP,GN 21-24 (add +7 to previous GP,GN numbers)
Pin Number  Pin Function         Mnemonic  ULX3S
Pin 1       Chip Select          CS        GN24  LED0
Pin 2       Master Out Slave In  MOSI      GN23  LED1
Pin 3       Master In Slave Out  MISO      GN22  LED2
Pin 4       Serial Clock         SCLK      GN21  LED3
Pin 5       Digital Ground       DGND
Pin 6       Digital Power        VDD
Pin 7       Interrupt 1          INT1      GP24  LED4
Pin 8       Not Connected        NC        GP23
Pin 9       Interrupt 2          INT2      GP22  LED6
Pin 10      Data Ready           DRDY      GP21  LED7
Pin 11      Digital Ground       DGND
Pin 12      Digital Power        VDD
*/

`default_nettype none
module top_adxl355log
#(
  ram_len      = 9*1024,    // buffer size 3,6,9,12,15
  C_prog_release_timeout = 26, // esp32 programming default n=26, 2^n / 25MHz = 2.6s
  spi_direct   = 0,          // 0: spi slave (SPI_MODE3), 1: direct to adxl (SPI_MODE1 or SPI_MODE3)
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
  output        gp13, // ESP32   MISO
  output        gp14, // ADXL355 DRDY
  input         gp15, // ADXL355 INT2
  input         gp17, // ADXL355 INT1
  input         gn15, // ADXL355 MISO
  output        gn14,gn16,gn17, // ADXL355 SCLK,MOSI,CSn
  output        gp21, // ADXL355 DRDY
  input         gp22, // ADXL355 INT2
  input         gp24, // ADXL355 INT1
  input         gn22, // ADXL355 MISO
  output        gn21,gn23,gn24, // ADXL355 SCLK,MOSI,CSn
  input         gn11, // ESP32 wifi_gpio26 PPS to FPGA
  output        gp11, // ESP32 wifi_gpio26 PPS feedback
  input         ftdi_nrts,
  input         ftdi_ndtr,
  output        ftdi_rxd,
  input         ftdi_txd,
  output        wifi_en,
  output        wifi_rxd,
  input         wifi_txd,
  inout         wifi_gpio0,
  input         wifi_gpio5,
  input         wifi_gpio16, wifi_gpio17,
  inout   [3:0] sd_d, // wifi_gpio 13,12,4,2
  input         sd_cmd, sd_clk,
  output        sd_wp // BGA pin exists but not connected on PCB
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

  // detecting programming ESP32 and reset timeout
  reg [C_prog_release_timeout:0] R_prog_release;
  always @(posedge clk_25mhz)
  begin
    R_prog_in <= S_prog_in;
    if(S_prog_out == 2'b01 && R_prog_in == 2'b11)
      R_prog_release <= 0; // keep resetting during ESP32 programming
    else
      if(R_prog_release[C_prog_release_timeout] == 1'b0)
        R_prog_release <= R_prog_release + 1; // increment until MSB=0
  end
  // wifi_gpio2 for programming must go together with wifi_gpio0
  // wifi_gpio12 (must be 0 for esp32 fuse unprogrammed)
  assign sd_d  = R_prog_release[C_prog_release_timeout] ? 4'hz : { 3'b101, S_prog_out[0] }; // wifi_gpio 13,12,4,2
  assign sd_wp = sd_clk | sd_cmd | sd_d; // force pullup for 4'hz above for listed inputs to make SD MMC mode work
  // sd_wp is not connected on PCB, just to prevent optimizer from removing pullups

  assign wifi_en = S_prog_out[1];
  assign wifi_gpio0 = R_prog_release[C_prog_release_timeout] ? 1'bz : S_prog_out[0] & btn[0]; // holding BTN0 will hold gpio0 LOW, signal for ESP32 to take control

  //assign wifi_en = S_prog_out[1] & btn[0]; // holding BTN0 disables ESP32, releasing BTN0 reboots ESP32
  //assign wifi_gpio0 = S_prog_out[0];

  wire int1 = gp17;
  wire int2 = gp15;
  wire drdy; // gp14;
  assign gp14 = drdy; // adxl0 
  assign gp21 = drdy; // adxl1

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

  wire csn, mosi, miso, sclk;
  wire rd_csn, rd_mosi, rd0_miso, rd1_miso, rd_sclk; // spi reader

  wire        ram_rd, ram_wr;
  wire [31:0] ram_addr;
  wire  [7:0] ram_di, ram_do;

  wire spi_ram_wr, spi_ram_x;
  wire  [7:0] spi_ram_data;
  localparam ram_addr_bits = $clog2(ram_len-1);
  reg [ram_addr_bits-1:0] spi_ram_addr = 0, r_spi_ram_addr;
  reg [7:0] ram[0:ram_len-1];
  reg [7:0] R_ram_do;
  wire spi_ram_miso; // muxed
  wire spi_bram_cs; // "chip" select line for address detection of bram buffer addr 0x00...
  wire spi_ctrl_cs; // control byte select addr 0xFF..
  reg [7:0] r_ctrl = 8'h00; // control byte, r_ctrl[7:2]:reserved, r_ctrl[1]:direct_en, r_ctrl[0]:reserved
  wire direct_req = r_ctrl[1]; // mux switch 1:direct, 0:reader core
  wire direct_en;

  generate
  if(spi_direct)
  begin
    // ADXL355 connections (FPGA is master to ADXL355)
    assign gn17 = csn;
    assign gn16 = mosi;
    assign miso = gn15;
    assign gn14 = ~sclk; // invert sclk to use SPI_MODE3 instead of SPI_MODE1
  end
  else
  begin
    // ADXL355 0 connections (FPGA is master to ADXL355)
    assign gn17 = direct_en ?  csn  : rd_csn;
    assign gn14 = direct_en ? ~sclk : rd_sclk;
    assign gn16 = direct_en ?  mosi : rd_mosi;
    assign miso = direct_en ?  gn15 : spi_ram_miso; // mux miso to esp32
    assign rd0_miso = gn15; // adxl0 miso directly to reader core

    // ADXL355 1 connections (FPGA is master to ADXL355)
    assign gn24 = direct_en ?  csn  : rd_csn;
    assign gn21 = direct_en ? ~sclk : rd_sclk;
    assign gn23 = direct_en ?  mosi : rd_mosi;
    assign rd1_miso = gn22; // adxl1 miso directly to reader core

    spirw_slave_v
    #(
        .c_addr_bits(32),
        .c_sclk_capable_pin(1'b0)
    )
    spirw_slave_v_inst
    (
        .clk(clk),
        .csn(csn),
        .sclk(sclk),
        .mosi(mosi),
        .miso(spi_ram_miso), // muxed for direct
        .rd(ram_rd),
        .wr(ram_wr),
        .addr(ram_addr),
        .data_in(ram_do),
        .data_out(ram_di)
    );
    assign spi_bram_cs = ram_addr[31:24] == 8'h00 ? 1 : 0; // currently unused
    assign spi_ctrl_cs = ram_addr[31:24] == 8'hFF ? 1 : 0;
    //assign ram_do = ram_addr[7:0];
    //assign ram_do = 8'h5A;
    always @(posedge clk)
    begin
      if(spi_ram_wr) // SPI reader core writes
      begin
        // invert bit[0] to swap lsb/msb byte for wav format
        ram[spi_ram_addr^1] <= spi_ram_data; // SPI reader core provided write address
        if(spi_ram_addr == ram_len-1) // auto-increment and wraparound
          spi_ram_addr <= 0;
        else
          spi_ram_addr <= spi_ram_addr + 1;
      end
      if(ram_rd)
      begin
        if(ram_addr[31:24] == 8'h01 && ram_addr[0] == 1'b0)
          r_spi_ram_addr <= spi_ram_addr; // latch address MSB
        // ram_addr: SPI slave core provided read address
        // spi_ram_addr: SPI reader core autoincrementing address
        R_ram_do <= ram_addr[31:24] == 8'h00 ? ram[ram_addr]
                  : ram_addr[31:24] == 8'h01 ? (ram_addr[0] ? r_spi_ram_addr[ram_addr_bits-1:8] : r_spi_ram_addr[7:0])
                  //: ram_addr[31:24] == 8'h02 ? (ram_addr[0] ?   spi_ram_addr[ram_addr_bits-1:8] :   spi_ram_addr[7:0]) // debug to check latched values
                  : 0;
      end
    end
    assign ram_do = R_ram_do;
    //assign ram_do = spi_ram_data; // debug
    //assign ram_do = 8'h5A; // debug
    always @(posedge clk)
    begin
      if(ram_wr && spi_ctrl_cs) // spi slave writes ctrl byte
        r_ctrl <= ram_di;
    end
  end
  endgenerate

  // ESP32 connections direct to ADXL355 (FPGA is slave for ESP32)
  assign csn  = wifi_gpio17;
  assign mosi = wifi_gpio16;
  assign gp13 = miso; // wifi_gpio35 v2.1.2
  //assign gp13 = 0; // debug, should print 00
  //assign gp13 = 1; // debug, should print FF
  assign sclk = wifi_gpio0;

  // generate PPS signal (1 Hz, 100 ms duty cycle)
  localparam pps_cnt_max = clk_out0_hz*pps_s/pps_n; // cca +-20000 tolerance
  localparam pps_width   = pps_cnt_max/10;   
  reg [$clog2(pps_cnt_max)-1:0] pps_cnt;
  reg pps, pps_pulse;
  always @(posedge clk)
  begin
    if(pps_cnt == pps_cnt_max-1)
    begin
      pps_cnt <= 0;
      pps_pulse <= 1;
    end
    else
    begin
      pps_cnt <= pps_cnt+1;
      pps_pulse <= 0;
    end
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


  // rising edge detection of drdy (sync)
  reg [1:0] r_sync_shift;
  reg sync_pulse;
  always @(posedge clk)
  begin
    r_sync_shift <= {drdy, r_sync_shift[1]};
    sync_pulse <= r_sync_shift == 2'b10 ? 1 : 0;
  end

  // SPI reader
  // counter for very slow clock
  localparam slowdown = 0;
  reg [slowdown:0] r_sclk_en;
  always @(posedge clk)
  begin
    if(r_sclk_en[slowdown])
      r_sclk_en <= 0;
    else
      r_sclk_en <= r_sclk_en+1;
  end
  wire sclk_en = r_sclk_en[slowdown];

  adxl355rd
  adxl355rd_inst
  (
    .clk(clk), .clk_en(sclk_en),
    .direct(direct_req),
    .direct_en(direct_en),
    .cmd(8*2+1), // 0*2+1 to read id, 8*2+1 to read xyz, 17*2+1 to read fifo
    .len(10), // 10 = 1+9, 1 byte transmitted and 9 bytes received
    .tag_pulse(pps_pulse),
    .tag_en(0),  // TODO write signal from SPI
    .tag(6'h30), // TODO 6-bit char from SPI
    .sync(sync_pulse),
    .adxl_csn(rd_csn),
    .adxl_sclk(rd_sclk),
    .adxl_mosi(rd_mosi),
    .adxl0_miso(rd0_miso), // normal
    .adxl1_miso(rd1_miso), // normal
    //.adxl0_miso(0), // debug
    //.adxl1_miso(0), // debug
    .wrdata(spi_ram_data),
    .wr16(spi_ram_wr), // skips every 3rd byte
    .x(spi_ram_x)
  );
  // test memory write cycle
  reg [7:0] r_wrdata;
  always @(posedge clk)
  begin
    if(spi_ram_wr)
      r_wrdata <= spi_ram_data;
  end

  //assign led = {spi_ram_x, spi_ram_wr, rd_miso, rd_mosi, rd_sclk, rd_csn};
  //assign led = r_wrdata;
  //assign led = r_ctrl;

  assign audio_l[3:1] = 0;
  assign audio_l[0] = drdy;
  assign audio_r[3:1] = 0;
  assign audio_r[0] = pps_btn;

  assign oled_csn = 0; // st7789 backlight off

endmodule
`default_nettype wire
