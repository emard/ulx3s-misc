// AUTHOR=EMARD
// LICENSE=BSD

`default_nettype none
module ulx3s_collatz_test
#(
parameter collatz_bits  = 160,
parameter msb0_bits     =  64,      // MSB zero bits
parameter C_display     = "ST7789", // "SSD1331", "ST7789"
parameter C_disp_bits   = 256
)
(
input wire clk_25mhz,
/*
output wire ftdi_rxd,
input wire ftdi_txd,
inout wire ftdi_ndtr,
inout wire ftdi_ndsr,
inout wire ftdi_nrts,
inout wire ftdi_txden,
*/
//output wire wifi_rxd,
//input wire wifi_txd,
inout wire wifi_en,
inout wire wifi_gpio0,
//inout wire wifi_gpio2,
//inout wire wifi_gpio15,
//inout wire wifi_gpio16,
output wire [7:0] led,
input  wire [6:0] btn,
input  wire [3:0] sw,
//input wire [1:4] sw,
output wire oled_csn,
output wire oled_clk,
output wire oled_mosi,
output wire oled_dc,
output wire oled_resn,

input  wire ftdi_txd,
output wire ftdi_rxd,
input  wire wifi_txd,
output wire wifi_rxd,

inout wire [27:0] gp,
inout wire [27:0] gn,
/*
input wire usb_fpga_dp,
inout wire usb_fpga_bd_dp,
inout wire usb_fpga_bd_dn,
output wire usb_fpga_pu_dp,
output wire usb_fpga_pu_dn,
*/
output wire [3:0] gpdi_dp,
output wire shutdown
);

  wire clk_125MHz, clk_25MHz; // video
  reg  [C_disp_bits-1:0] R_disp;
  wire clk_pixel, clk_shift;  // 25,125 MHz
  wire [9:0] beam_x, beam_rx, beam_y;
  wire [15:0] color;
  wire vga_hsync, vga_vsync, vga_blank;
  wire [7:0] vga_r, vga_g, vga_b;
  wire [1:0] dvid_red, dvid_green, dvid_blue, dvid_clock;

  // TX/RX passthru
  assign ftdi_rxd = wifi_txd;
  assign wifi_rxd = ftdi_txd;

  assign shutdown = 0;
  
  wire w_locked;
  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(125*1000000),                 .out0_tol_hz(0),
    .out1_hz( 25*1000000), .out1_deg(  0), .out1_tol_hz(0),
    .out2_hz( 25*1000000), .out2_deg(  0), .out2_tol_hz(0),
    .out3_hz( 25*1000000), .out3_deg(  0), .out3_tol_hz(0)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(w_locked)
  );
  assign clk_125MHz = clocks[0];
  assign clk_shift  = clocks[0];
  assign clk_pixel  = clocks[1];
  assign clk        = clk_125MHz;

  wire [6:0] btn_rising, btn_debounce;
  btn_debounce
  #(
    .bits(22)
  )
  btn_debounce_inst
  (
    .clk(clk),
    .btn(btn),
    .rising(btn_rising),
    .debounce(btn_debounce)
  );

  reg clken;
  always @(posedge clk)
    clken <= btn_rising[1] | (sw[1]^btn_debounce[2]);

  wire [collatz_bits-1:0] val_start, val_actual;
  collatz_conjecture
  #(
    .msb0_bits(msb0_bits),  // standoff MSB bits 0, rest bits 1
    .bits(collatz_bits)     // integer arithmetic bits
  )
  collatz_conjecture_inst
  (
    .clk(clk),
    .clken(clken),
    .start(val_start),
    .actual(val_actual)
  );
  assign led = val_start[23:16];
  
  always @(posedge clk)
  begin
    if(vga_vsync)
    begin
      R_disp[127:  0] <= val_start [127:0];
      R_disp[255:128] <= val_actual[127:0];
    end
  end

  //ftdi_rxd <= wifi_txd;
  //wifi_rxd <= ftdi_txd;
  assign wifi_en = 1'b1;
  assign wifi_gpio0 = btn[0];

  generate
  if(C_display == "SSD1331")
  begin
  wire  [6:0] disp_x;
  wire  [5:0] disp_y;
  wire [15:0] disp_color;
  hex_decoder_v
  #(
    .c_data_len(C_disp_bits),
    .c_font_file("hex_font.mem"),
    .c_row_bits(5),
    .c_grid_6x8(1),
    //.c_x_bits(7),
    //.c_y_bits(6),
    .c_color_bits(16)
  )
  hex_decoder_oled_inst
  (
    .clk(clk_25MHz),
    .data(R_disp),
    .x(disp_x),
    .y(disp_y),
    .color(disp_color)
  );
  lcd_video
  #(
    .c_init_file("ssd1331_linit_xflip_16bit.mem"),
    .c_init_size(90),
    .c_reset_us(1000),
    .c_clk_phase(0),
    .c_clk_polarity(1),
    .c_x_size(96),
    .c_y_size(64),
    .c_color_bits(16),
    .c_clk_mhz(25)
  )
  lcd_video_inst
  (
    .clk(clk_25MHz),
    .reset(btn_debounce[3]),
    .x(disp_x),
    .y(disp_y),
    .color(disp_color),
    .spi_csn(oled_csn),
    .spi_clk(oled_clk),
    .spi_mosi(oled_mosi),
    .spi_dc(oled_dc),
    .spi_resn(oled_resn)
  );
  end
  if(C_display == "ST7789")
  begin
  wire  [7:0] disp_x;
  wire  [7:0] disp_y;
  wire [15:0] disp_color;
  hex_decoder_v
  #(
    .c_data_len(C_disp_bits),
    .c_font_file("hex_font.mem"),
    .c_row_bits(5),
    .c_grid_6x8(1),
    //.c_x_bits(8),
    //.c_y_bits(8),
    .c_color_bits(16)
  )
  hex_decoder_oled_inst
  (
    .clk(clk_125MHz),
    .data(R_disp),
    .x(disp_x[7:1]),
    .y(disp_y[7:1]),
    .color(disp_color)
  );
  wire spi_csn;
  lcd_video
  #(
    .c_init_file("st7789_linit_xflip.mem"),
    .c_init_size(35),
    .c_clk_spi_mhz(125)
  )
  lcd_video_inst
  (
    .reset(btn_debounce[3]),
    .clk_pixel(clk_125MHz),
    .clk_spi(clk_125MHz),
    .x(disp_x),
    .y(disp_y),
    .color(disp_color),
    .spi_csn(spi_csn),
    .spi_clk(oled_clk),
    .spi_mosi(oled_mosi),
    .spi_dc(oled_dc),
    .spi_resn(oled_resn)
  );
  assign oled_csn = spi_csn | ~btn_debounce[5];
  end
  endgenerate

  assign beam_rx = 636 - beam_x;
  // HEX decoder needs reverse X-scan, few pixels adjustment for pipeline delay
  hex_decoder_v
  #(
    .c_data_len(C_disp_bits),
    .c_row_bits(5), // 2**n digits per row (4*2**n bits/row) 3->32, 4->64, 5->128, 6->256
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_x_bits(8),
    .c_y_bits(5),
    .c_color_bits(16)
  )
  hex_decoder_dvi_instance
  (
    .clk(clk_pixel),
    .data(R_disp),
    .x(beam_rx[9:2]),
    .y(beam_y[6:2]),
    .color(color)
  );

  vga
  vga_instance
  (
    .clk_pixel(clk_pixel),
    .clk_pixel_ena(1'b1),
    .test_picture(1'b0),
    .beam_x(beam_x),
    .beam_y(beam_y),
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .vga_blank(vga_blank)
  );

  assign vga_r = {color[15:11],color[11],color[11],color[11]};
  assign vga_g = {color[10:5],color[5],color[5]};
  assign vga_b = {color[4:0],color[0],color[0],color[0]};
  vga2dvid
  #(
    .c_ddr(1'b1),
    .c_shift_clock_synchronizer(1'b0)
  )
  vga2dvid_instance
  (
    .clk_pixel(clk_pixel),
    .clk_shift(clk_shift),
    .in_red(vga_r),
    .in_green(vga_g),
    .in_blue(vga_b),
    .in_hsync(vga_hsync),
    .in_vsync(vga_vsync),
    .in_blank(vga_blank),
    // single-ended output ready for differential buffers
    .out_red(dvid_red),
    .out_green(dvid_green),
    .out_blue(dvid_blue),
    .out_clock(dvid_clock)
  );

  // vendor specific DDR modules
  // convert SDR 2-bit input to DDR clocked 1-bit output (single-ended)
  ODDRX1F ddr_clock(
    .D0(dvid_clock[0]),
    .D1(dvid_clock[1]),
    .Q(gpdi_dp[3]),
    .SCLK(clk_shift),
    .RST(1'b0));

  ODDRX1F ddr_red(
    .D0(dvid_red[0]),
    .D1(dvid_red[1]),
    .Q(gpdi_dp[2]),
    .SCLK(clk_shift),
    .RST(1'b0));

  ODDRX1F ddr_green(
    .D0(dvid_green[0]),
    .D1(dvid_green[1]),
    .Q(gpdi_dp[1]),
    .SCLK(clk_shift),
    .RST(1'b0));

  ODDRX1F ddr_blue(
    .D0(dvid_blue[0]),
    .D1(dvid_blue[1]),
    .Q(gpdi_dp[0]),
    .SCLK(clk_shift),
    .RST(1'b0));

endmodule
`default_nettype wire
