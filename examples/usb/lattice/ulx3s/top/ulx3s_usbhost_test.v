// File /home/guest/tmp/ulx3s_usbhost_test.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
// vhd2vl settings:
//  * Verilog Module Declaration Style: 2001

// vhd2vl is Free (libre) Software:
//   Copyright (C) 2001 Vincenzo Liguori - Ocean Logic Pty Ltd
//     http://www.ocean-logic.com
//   Modifications Copyright (C) 2006 Mark Gonzales - PMC Sierra Inc
//   Modifications (C) 2010 Shankar Giri
//   Modifications Copyright (C) 2002-2017 Larry Doolittle
//     http://doolittle.icarus.com/~larry/vhd2vl/
//   Modifications (C) 2017 Rodrigo A. Melo
//
//   vhd2vl comes with ABSOLUTELY NO WARRANTY.  Always check the resulting
//   Verilog for correctness, ideally with a formal verification tool.
//
//   You are welcome to redistribute vhd2vl under certain conditions.
//   See the license (GPLv2) file included with the source for details.

// The result of translation follows.  Its copyright status should be
// considered unchanged from the original VHDL.

// (c)EMARD
// License=BSD

module ulx3s_usbhost_test
#(
parameter C_usb_speed=1'b0, // 0:6 MHz USB1.0, 1:48 MHz USB1.1
parameter C_report_bytes = 20, // 8:usual gamepad, 20:xbox360
// enable only one US2/US3/US4 (currently only US2 supported)
parameter C_display="SSD1331", // "SSD1331", "ST7789"
parameter C_us2=1,
parameter C_us3=0,
parameter C_us4=0
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
/*
inout wire [27:0] gp,
inout wire [27:0] gn,
*/
input wire usb_fpga_dp,
inout wire usb_fpga_bd_dp,
inout wire usb_fpga_bd_dn,
output wire usb_fpga_pu_dp,
output wire usb_fpga_pu_dn,
output wire [3:0] gpdi_dp,
output wire shutdown
);

// main clock input from 25MHz clock source
// UART0 (FTDI USB slave serial)
// FTDI additional signaling
// UART1 (WiFi serial)
// WiFi additional signaling
// '0' will disable wifi by default
// Onboard blinky
// GPIO (some are shared with wifi and adc)
// FPGA direct USB connector
// differential or single-ended input
// only for single-ended input
// single ended bidirectional
// pull up for slave, down for host mode

// PMOD with US3 and US4
// ULX3S pins up and flat cable: swap GP/GN and invert differential input
// ULX3S direct or pins down and flat cable: don't swap GP/GN, normal differential input
//  alias us3_fpga_bd_dp: std_logic is gn(25);
//  alias us3_fpga_bd_dn: std_logic is gp(25);
//  alias us4_fpga_bd_dp: std_logic is gn(24);
//  alias us4_fpga_bd_dn: std_logic is gp(24);
//  alias us4_fpga_pu_dp: std_logic is gn(23);
//  alias us4_fpga_pu_dn: std_logic is gp(23);
//  alias us3_fpga_pu_dp: std_logic is gn(22);
//  alias us3_fpga_pu_dn: std_logic is gp(22);
//  alias us3_fpga_n_dp: std_logic is gp(21); -- flat cable
//  signal us3_fpga_dp: std_logic; -- flat cable
//alias us3_fpga_dp: std_logic is gp(21); -- direct
//  alias us4_fpga_n_dp: std_logic is gp(20); -- flat cable
//  signal us4_fpga_dp: std_logic; -- flat cable
//alias us4_fpga_dp: std_logic is gp(20); -- direct

wire clk_125MHz, clk_25MHz; // video
wire clk_48MHz, clk_6MHz; // usb
wire clk_usb;  // 6 MHz USB1.0 or 48 MHz USB1.1
wire [C_report_bytes*8-1:0] S_report;
wire [127:0] S_oled;
wire S_valid;
wire clk_pixel; wire clk_shift;  // 25,125 MHz
wire [9:0] beam_x; wire [9:0] beam_rx; wire [9:0] beam_y;
wire [15:0] color;
wire vga_hsync; wire vga_vsync; wire vga_blank;
wire [7:0] vga_r; wire [7:0] vga_g; wire [7:0] vga_b;
wire [1:0] dvid_red; wire [1:0] dvid_green; wire [1:0] dvid_blue; wire [1:0] dvid_clock;

assign shutdown = 0;

  clk_25_125_48_6_25 clk_single_pll1
  (
    .clk25_i(clk_25mhz),
    .clk125_o(clk_125MHz),
    .clk48_o(clk_48MHz),
    .clk6_o(clk_6MHz),
    .clk25_o(clk_25MHz)
  );
  assign clk_shift = clk_125MHz;
  assign clk_pixel = clk_25MHz;

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
  //  G_us2: if C_us2=1 generate
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
    .usb_dif(usb_fpga_bd_dp), // for trellis < 2020-03-08
    //.usb_dif(usb_fpga_dp),
    .usb_dp(usb_fpga_bd_dp),
    .usb_dn(usb_fpga_bd_dn),
    .hid_report(S_report),
    .hid_valid(S_valid)
  );
  //  end generate; // US2

  //  G_us3: if C_us3 generate
  //  us3_fpga_pu_dp <= '0';
  //  us3_fpga_pu_dn <= '0';
  //  us3_fpga_dp <= not us3_fpga_n_dp; -- flat cable
  //  us3_hid_host_inst: entity usbh_host_hid
  //  generic map
  //  (
  //    C_usb_speed => C_usb_speed -- '0':Low-speed '1':Full-speed
  //  )
  //  port map
  //  (
  //    clk => clk_usb, -- 6 MHz for low-speed USB1.0 device or 48 MHz for full-speed USB1.1 device
  //    bus_reset => '0',
  //    usb_dif => us3_fpga_dp,    -- usb/us3/us4
  //    usb_dp  => us3_fpga_bd_dp, -- usb/us3/us4
  //    usb_dn  => us3_fpga_bd_dn, -- usb/us3/us4
  //    hid_report => S_report,
  //    hid_valid => S_valid
  //  );
  //  end generate;
  //  G_us4: if C_us4 generate
  //  us4_fpga_pu_dp <= '0';
  //  us4_fpga_pu_dn <= '0';
  //  us4_fpga_dp <= not us4_fpga_n_dp; -- flat cable
  //  us4_hid_host_inst: entity usbh_host_hid
  //  generic map
  //  (
  //    C_usb_speed => C_usb_speed -- '0':Low-speed '1':Full-speed
  //  )
  //  port map
  //  (
  //    clk => clk_usb, -- 6 MHz for low-speed USB1.0 device or 48 MHz for full-speed USB1.1 device
  //    bus_reset => '0',
  //    usb_dif => us4_fpga_dp,    -- usb/us3/us4
  //    usb_dp  => us4_fpga_bd_dp, -- usb/us3/us4
  //    usb_dn  => us4_fpga_bd_dn, -- usb/us3/us4
  //    hid_report => S_report,
  //    hid_valid => S_valid
  //  );
  //  end generate;

  always @(posedge clk_usb)
    if(S_valid)
      S_oled[127:0] <= S_report[127:0];

  generate
  if(C_display == "SSD1331")
  begin
  wire  [6:0] disp_x;
  wire  [5:0] disp_y;
  wire [15:0] disp_color;
  hex_decoder_v
  #(
    .c_data_len(128),
    .c_font_file("hex_font.mem"),
    .c_row_bits(4),
    .c_grid_6x8(1),
    .c_color_bits(16)
  )
  hex_decoder_oled_inst
  (
    .clk(clk_25MHz),
    .data(S_oled),
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
    .c_data_len(128),
    .c_font_file("hex_font.mem"),
    .c_row_bits(4),
    .c_grid_6x8(1),
    .c_color_bits(16)
  )
  hex_decoder_oled_inst
  (
    .clk(clk_125MHz),
    .data(S_oled),
    .x(disp_x[7:1]),
    .y(disp_y[7:1]),
    .color(disp_color)
  );
  lcd_video
  #(
    .c_init_file("st7789_linit_xflip.mem"),
    .c_init_size(38),
    .c_clk_mhz(125)
  )
  lcd_video_inst
  (
    .clk(clk_125MHz),
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
  endgenerate

  assign beam_rx = 636 - beam_x;
  // HEX decoder needs reverse X-scan, few pixels adjustment for pipeline delay
  hex_decoder_v
  #(
    .c_data_len(128),
    .c_row_bits(4), // 2**n digits per row (4*2**n bits/row) 3->32, 4->64, 5->128, 6->256
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_x_bits(8),
    .c_y_bits(4),
    .c_color_bits(16)
  )
  hex_decoder_dvi_instance
  (
    .clk(clk_pixel),
    .data(S_oled),
    .x(beam_rx[9:2]),
    .y(beam_y[5:2]),
    .color(color)
  );

  vga
  vga_instance
  (
    .clk_pixel(clk_pixel),
    .clk_pixel_ena(1'b1),
    .test_picture(1'b1),
    .beam_x(beam_x),
    .beam_y(beam_y),
    .red_byte(/* open */),
    .green_byte(/* open */),
    .blue_byte(/* open */),
    .vga_r(/* open */),
    .vga_g(/* open */),
    .vga_b(/* open */),
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .vga_blank(vga_blank)
  );

  assign vga_r = {color[15:11],color[11],color[11],color[11]};
  assign vga_g = {color[10:5],color[5],color[5]};
  assign vga_b = {color[4:0],color[0],color[0],color[0]};
  vga2dvid
  #(
    .C_ddr(1'b1),
    .C_shift_clock_synchronizer(1'b0)
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
