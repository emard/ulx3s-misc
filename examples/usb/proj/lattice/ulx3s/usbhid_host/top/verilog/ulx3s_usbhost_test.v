// AUTHOR=EMARD
// LICENSE=BSD

module ulx3s_usbhost_test
#(
parameter C_usb_speed=1'b0, // 0:6 MHz USB1.0, 1:48 MHz USB1.1
parameter C_report_bytes = 20, // 8:usual gamepad, 20:xbox360
parameter C_display="ST7789", // "SSD1331", "ST7789"
parameter C_disp_bits=256,
// enable ports: 1:enabled, 0:disabled
parameter C_us2=1, 
parameter C_us3=1,
parameter C_us4=1
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
input wire [6:0] btn,
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

input wire usb_fpga_dp,
inout wire usb_fpga_bd_dp,
inout wire usb_fpga_bd_dn,
output wire usb_fpga_pu_dp,
output wire usb_fpga_pu_dn,
output wire [3:0] gpdi_dp,
output wire shutdown
);

// PMOD with US3 and US4
// ULX3S direct or pins down and flat cable: don't swap GP/GN, normal differential input
// ULX3S pins up and flat cable: swap GP/GN and invert differential input

wire clk_125MHz, clk_25MHz; // video
wire clk_48MHz, clk_6MHz; // usb
wire clk_usb;  // 6 MHz USB1.0 or 48 MHz USB1.1
wire [C_report_bytes*8-1:0] S_report[0:2];
reg  [C_disp_bits-1:0] R_disp;
wire [2:0] S_valid;
wire clk_pixel; wire clk_shift;  // 25,125 MHz
wire [9:0] beam_x; wire [9:0] beam_rx; wire [9:0] beam_y;
wire [15:0] color;
wire vga_hsync; wire vga_vsync; wire vga_blank;
wire [7:0] vga_r; wire [7:0] vga_g; wire [7:0] vga_b;
wire [1:0] dvid_red; wire [1:0] dvid_green; wire [1:0] dvid_blue; wire [1:0] dvid_clock;

// TX/RX passthru
assign ftdi_rxd = wifi_txd;
assign wifi_rxd = ftdi_txd;

assign shutdown = 0;
  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(125*1000000),                 .out0_tol_hz(0),
    .out1_hz( 25*1000000), .out1_deg(  0), .out1_tol_hz(0),
    .out2_hz( 48*1000000), .out2_deg(  0), .out2_tol_hz(100000),
    .out3_hz(  6*1000000), .out3_deg(  0), .out3_tol_hz(10000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks)
  );
  assign clk_125MHz= clocks[0];
  assign clk_shift = clocks[0];
  assign clk_pixel = clocks[1];
  assign clk_48MHz = clocks[2];
  assign clk_6MHz  = clocks[3];

  //ftdi_rxd <= wifi_txd;
  //wifi_rxd <= ftdi_txd;
  assign wifi_en = 1'b1;
  assign wifi_gpio0 = btn[0];
  generate if (C_usb_speed == 1'b0) begin: G_low_speed
      assign clk_usb = clk_6MHz;
  end
  endgenerate
  generate if (C_usb_speed == 1'b1) begin: G_full_speed
      assign clk_usb = clk_48MHz;
  end
  endgenerate

  generate
    if(C_us2==1)
    begin
      assign usb_fpga_pu_dp = 1'b0;
      assign usb_fpga_pu_dn = 1'b0;
      usbh_host_hid
      #(
        .C_report_length(C_report_bytes),
        .C_report_length_strict(0),
        .C_usb_speed(C_usb_speed) // '0':Low-speed '1':Full-speed
      )
      us2_hid_host_inst
      (
        .clk(clk_usb), // 6 MHz for low-speed USB1.0 device or 48 MHz for full-speed USB1.1 device
        .bus_reset(~btn[0]),
        .led(led), // debug output
        //.usb_dif(usb_fpga_bd_dp), // for trellis < 2020-03-08
        .usb_dif(usb_fpga_dp),
        .usb_dp(usb_fpga_bd_dp),
        .usb_dn(usb_fpga_bd_dn),
        .hid_report(S_report[0]),
        .hid_valid(S_valid[0])
      );
      always @(posedge clk_usb)
        if(S_valid[0])
          R_disp[63:0] <= S_report[0][63:0];
    end
  endgenerate // US2

  generate
    if(C_us3==1)
    begin
      assign gp[23] = 1'b0; // pull down
      assign gn[23] = 1'b0; // pull down
      usbh_host_hid
      #(
        .C_report_length(C_report_bytes),
        .C_report_length_strict(0),
        .C_usb_speed(C_usb_speed) // '0':Low-speed '1':Full-speed
      )
      us3_hid_host_inst
      (
        .clk(clk_usb), // 6 MHz for low-speed USB1.0 device or 48 MHz for full-speed USB1.1 device
        .bus_reset(~btn[0]),
        .led(), // debug output
        .usb_dif(gp[21]),
        .usb_dp(gp[25]),
        .usb_dn(gn[25]),
        .hid_report(S_report[1]),
        .hid_valid(S_valid[1])
      );
      always @(posedge clk_usb)
        if(S_valid[1])
          R_disp[127:64] <= S_report[1][63:0];
    end
  endgenerate // US3

  generate
    if(C_us4==1)
    begin
      assign gp[22] = 1'b0; // pull down
      assign gn[22] = 1'b0; // pull down
      usbh_host_hid
      #(
        .C_report_length(C_report_bytes),
        .C_report_length_strict(0),
        .C_usb_speed(C_usb_speed) // '0':Low-speed '1':Full-speed
      )
      us4_hid_host_inst
      (
        .clk(clk_usb), // 6 MHz for low-speed USB1.0 device or 48 MHz for full-speed USB1.1 device
        .bus_reset(~btn[0]),
        .led(), // debug output
        .usb_dif(gp[20]),
        .usb_dp(gp[24]),
        .usb_dn(gn[24]),
        .hid_report(S_report[2]),
        .hid_valid(S_valid[2])
      );
      always @(posedge clk_usb)
        if(S_valid[2])
          R_disp[191:128] <= S_report[2][63:0];
    end
  endgenerate // US3

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
    .c_row_bits(4),
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
    .reset(~btn[0]),
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
    .c_row_bits(4),
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
    .reset(~btn[0]),
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
  assign oled_csn = spi_csn | ~btn[1];
  end
  endgenerate

  assign beam_rx = 636 - beam_x;
  // HEX decoder needs reverse X-scan, few pixels adjustment for pipeline delay
  hex_decoder_v
  #(
    .c_data_len(C_disp_bits),
    .c_row_bits(4), // 2**n digits per row (4*2**n bits/row) 3->32, 4->64, 5->128, 6->256
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
