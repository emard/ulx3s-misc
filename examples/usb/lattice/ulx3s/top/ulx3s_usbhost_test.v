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
// no timescale needed

module ulx3s_usbhost_test
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
/*
output wire oled_csn,
output wire oled_clk,
output wire oled_mosi,
output wire oled_dc,
output wire oled_resn,
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

parameter C_report_length = 20;
// enable only one US2/US3/US4
parameter [31:0] C_us2=1;
parameter [31:0] C_us3=0;
parameter [31:0] C_us4=0;
parameter C_usb_speed=1'b0;
// 0:6 MHz 1:48 MHz
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
// Digital Video (differential outputs)
// Flash ROM (SPI0)
//flash_miso   : in      std_logic;
//flash_mosi   : out     std_logic;
//flash_clk    : out     std_logic;
//flash_csn    : out     std_logic;
// SD card (SPI1)
//sd_d: inout std_logic_vector(3 downto 0) := (others => 'Z');
//sd_clk, sd_cmd: inout std_logic := 'Z';
//sd_cdn, sd_wp: inout std_logic := 'Z'; -- not connected
// SHUTDOWN: logic '1' here will shutdown power on PCB >= v1.7.5



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
wire clk_200MHz; wire clk_125MHz; wire clk_100MHz; wire clk_89MHz; wire clk_60MHz; wire clk_48MHz; wire clk_12MHz; wire clk_7M5Hz; wire clk_6MHz;
wire clk_usb;  // 48 MHz
wire R_phy_txmode;
wire S_rxd;
wire S_rxdp; wire S_rxdn;
wire S_txdp; wire S_txdn; wire S_txoe;
wire [C_report_length * 8 - 1:0] S_report;
wire [63:0] S_oled;
wire S_valid;
wire clk_pixel; wire clk_shift;  // 25,125 MHz
wire [9:0] beam_x; wire [9:0] beam_rx; wire [9:0] beam_y;
wire [15:0] color;
wire vga_hsync; wire vga_vsync; wire vga_blank;
wire [7:0] vga_r; wire [7:0] vga_g; wire [7:0] vga_b;
wire [1:0] dvid_red; wire [1:0] dvid_green; wire [1:0] dvid_blue; wire [1:0] dvid_clock;

assign shutdown = 0;

  //  g_single_pll: if true generate
/*
  clk_25M_100M_7M5_12M_60M clk_single_pll(
    .CLKI(clk_25mhz),
    .CLKOP(clk_100MHz),
    .CLKOS(clk_7M5Hz),
    .CLKOS2(clk_12MHz),
    .CLKOS3(clk_60MHz));
*/

  //  end generate;
  //  g_single_pll1: if true generate
  clk_25_125_68_6_25 clk_single_pll1(
    .clk25_i(clk_25mhz),
    .clk125_o(clk_shift),
    .clk68_o(/* open */),
    .clk6_o(clk_6MHz),
    .clk25_o(clk_pixel));

  //  end generate;
  //  g_single_pll2: if true generate
  /*
  clk_25_125_25_48_89 clk_single_pll2(
    .CLKI(clk_25mhz),
    .CLKOP(clk_shift),
    // 125 MHz
    .CLKOS(clk_pixel),
    // 25 MHz
    .CLKOS2(clk_48MHz),
    .CLKOS3(clk_89MHz));
  */

  //  end generate;
  //  g_double_pll: if false generate
  //  clk_double_pll1: entity work.clk_25M_200M
  //  port map
  //  (
  //      CLKI        =>  clk_25MHz,
  //      CLKOP       =>  clk_200MHz
  //  );
  //  clk_double_pll2: entity work.clk_200M_60M_48M_12M_7M5
  //  port map
  //  (
  //      CLKI        =>  clk_200MHz,
  //      CLKOP       =>  clk_60MHz,
  //      CLKOS       =>  clk_48MHz,
  //      CLKOS2      =>  clk_12MHz,
  //      CLKOS3      =>  clk_7M5Hz
  //  );
  //  end generate;
  // TX/RX passthru
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
    // '0':Low-speed '1':Full-speed
    .C_usb_speed(C_usb_speed)
  )
  us2_hid_host_inst(
    .clk(clk_usb),
    // 6 MHz for low-speed USB1.0 device or 48 MHz for full-speed USB1.1 device
    .bus_reset(~btn[0]),
    .led(led), // debug output
    .usb_dif(usb_fpga_bd_dp), // FIXME differential input usb_fpga_dp not working for trellis
    // usb/us3/us4
    .usb_dp(usb_fpga_bd_dp),
    // usb/us3/us4
    .usb_dn(usb_fpga_bd_dn),
    // usb/us3/us4
    .hid_report(S_report),
    .hid_valid(S_valid));

  //  end generate;
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

  assign S_oled = S_report[63:0];

//  oled_hex_decoder #(
//      .C_data_len(64))
//  oled_inst(
//      .clk(clk_6MHz),
//    .en(1'b1),
//    .data(S_oled[63:0]),
//    .spi_resn(oled_resn),
//    .spi_clk(oled_clk),
//    .spi_csn(oled_csn),
//    .spi_dc(oled_dc),
//    .spi_mosi(oled_mosi));

  assign beam_rx = 636 - beam_x;
  // HEX decoder needs reverse X-scan, few pixels adjustment for pipeline delay
  hex_decoder_v #(
    .c_data_len(64),
    .c_row_bits(5),
    // 2**n digits per row (4*2**n bits/row) 3->32, 4->64, 5->128, 6->256 
    .c_grid_6x8(1),
    // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_x_bits(8),
    .c_y_bits(4),
    .c_color_bits(16))
  hex_decoder_instance(
    .clk(clk_pixel),
    .data(S_oled),
    .x(beam_rx[9:2]),
    .y(beam_y[5:2]),
    .color(color));

  vga vga_instance(
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
    .vga_blank(vga_blank));

  assign vga_r = {color[15:11],color[11],color[11],color[11]};
  assign vga_g = {color[10:5],color[5],color[5]};
  assign vga_b = {color[4:0],color[0],color[0],color[0]};
  vga2dvid #(
    .C_ddr(1'b1),
    .C_shift_clock_synchronizer(1'b0))
  vga2dvid_instance(
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
    .out_clock(dvid_clock));

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
