`default_nettype none
module top_st7789_vga
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,
    output wire oled_csn,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire oled_resn
);
  assign wifi_en = 1;
  assign wifi_gpio0 = btn[0];

  localparam c_clk_pixel_mhz = 25;
  localparam c_clk_spi_mhz = 4*c_clk_pixel_mhz; // *4 or more

  // clock generator
  wire clk_locked;
  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz(25*1000000),
    .out0_hz(c_clk_spi_mhz*1000000),
    .out1_hz(c_clk_pixel_mhz*1000000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(clk_locked)
  );
  wire clk_lcd = clocks[0];
  wire clk_pixel = clocks[1];

  wire S_reset = ~btn[0] | btn[1];

  // test picture video generator for debug purposes
  wire vga_hsync;
  wire vga_vsync;
  wire vga_blank;
  wire [7:0] vga_r, vga_g, vga_b;
  vga
  #(
    .c_resolution_x(240),
    .c_hsync_front_porch(1800),
    .c_hsync_pulse(1),
    .c_hsync_back_porch(1800),
    .c_resolution_y(240),
    .c_vsync_front_porch(1),
    .c_vsync_pulse(1),
    .c_vsync_back_porch(1),
    .c_bits_x(12),
    .c_bits_y(8)
  )
  vga_instance
  (
    .clk_pixel(clk_pixel),
    .clk_pixel_ena(1'b1),
    .test_picture(1'b1),
    .vga_r(vga_r),
    .vga_g(vga_g),
    .vga_b(vga_b),
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .vga_blank(vga_blank)
  );
  wire [15:0] vga_rgb = {vga_r[7:3],vga_g[7:2],vga_b[7:3]};

  assign led[0] = ~vga_blank;
  assign led[1] =  vga_hsync;
  assign led[2] =  vga_vsync;
  assign led[3] = ~oled_resn;
  assign led[7:4] = 0;

  // OSD overlay
  wire [7:0] osd_vga_r, osd_vga_g, osd_vga_b;
  wire osd_vga_hsync, osd_vga_vsync, osd_vga_blank;
  spi_osd_v
  #(
    .c_sclk_capable_pin(1'b0),
    .c_start_x     ( 1), .c_start_y( 0), // xy centering
    .c_char_bits_x ( 5), .c_chars_y(15), // xy size, slightly less than full screen
    .c_bits_x      (12), .c_bits_y ( 8), // xy counters bits
    .c_inverse     ( 1),
    .c_transparency( 0),
    .c_init_on     ( 1),
    .c_char_file   ("osd.mem"),
    .c_font_file   ("font_bizcat8x16.mem")
  )
  spi_osd_v_instance
  (
    .clk_pixel(clk_pixel),
    .clk_pixel_ena(1'b1),
    .i_r(0),
    .i_g(0),
    .i_b(0),
    .i_hsync(vga_hsync),
    .i_vsync(vga_vsync),
    .i_blank(vga_blank),
    .i_csn(spi_csn),
    .i_sclk(spi_sck),
    .i_mosi(spi_mosi),
    .o_r(osd_vga_r),
    .o_g(osd_vga_g),
    .o_b(osd_vga_b),
    .o_hsync(osd_vga_hsync),
    .o_vsync(osd_vga_vsync),
    .o_blank(osd_vga_blank)
  );

  lcd_video
  #(
    .c_clk_spi_mhz(c_clk_spi_mhz),
    .c_vga_sync(1),
    .c_reset_us(1000),
    //.c_init_file("st7789_linit_long.mem"),
    //.c_init_size(75), // long init
    //.c_init_size(35), // standard init (not long)
    .c_clk_phase(0),
    .c_clk_polarity(1),
    .c_x_size(240),
    .c_y_size(240),
    .c_color_bits(16)
  )
  lcd_video_instance
  (
    .reset(S_reset),
    .clk_pixel(clk_pixel), // 25 MHz
    .clk_pixel_ena(1),
    .clk_spi(clk_lcd), // 100 MHz
    .clk_spi_ena(1),
    .blank(osd_vga_blank),
    .hsync(osd_vga_hsync),
    .vsync(osd_vga_vsync),
    .color({osd_vga_r,osd_vga_g}),
    .spi_resn(oled_resn),
    .spi_clk(oled_clk),
    //.spi_csn(oled_csn), // 8-pin ST7789
    .spi_dc(oled_dc),
    .spi_mosi(oled_mosi)
  );
  assign oled_csn = 1; // 7-pin ST7789

endmodule
`default_nettype wire
