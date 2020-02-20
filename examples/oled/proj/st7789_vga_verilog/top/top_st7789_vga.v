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
  wire S_reset = ~btn[0];

    // clock generator
    wire clk_250MHz, clk_125MHz, clk_25MHz, clk_locked;
    clk_25_250_125_25
    clock_instance
    (
      .clk25_i(clk_25mhz),
      //.clk250_o(clk_250MHz),
      .clk125_o(clk_125MHz),
      .clk25_o(clk_25MHz),
      .locked(clk_locked)
    );

  wire clk_pixel = clk_25MHz;
  wire clk_lcd = clk_125MHz; // up to clk_125MHz NOTE below lcd_video_inst .c_clk_mhz(125)

  // test picture video generator for debug purposes
  wire vga_hsync_test;
  wire vga_vsync_test;
  wire vga_blank_test;
  wire [7:0] vga_r_test, vga_g_test, vga_b_test;
  vga
  #(
    .C_resolution_x(240),
    .C_hsync_front_porch(1800),
    .C_hsync_pulse(1),
    .C_hsync_back_porch(1800),
    .C_resolution_y(240),
    .C_vsync_front_porch(1),
    .C_vsync_pulse(1),
    .C_vsync_back_porch(1),
    .C_bits_x(12),
    .C_bits_y(8)
  )
  vga_instance
  (
    .clk_pixel(clk_pixel),
    .clk_pixel_ena(1),
    .test_picture(1),
    .vga_r(vga_r_test),
    .vga_g(vga_g_test),
    .vga_b(vga_b_test),
    .vga_hsync(vga_hsync_test),
    .vga_vsync(vga_vsync_test),
    .vga_blank(vga_blank_test)
  );
  wire [15:0] vga_rgb_test = {vga_r_test[7:3],vga_g_test[7:2],vga_b_test[7:3]};
  
  reg [1:0] R_clk_pixel;
  always @(posedge clk_lcd)
    R_clk_pixel <= {clk_pixel,R_clk_pixel[1]}; 
  
  wire clk_pixel_ena = R_clk_pixel == 2'b10 ? 1 : 0;
  
  wire next_pixel;
  lcd_video
  #(
    .c_clk_mhz(125),
    .c_vga_sync(1),
    .c_x_size(240),
    .c_y_size(240),
    .c_color_bits(16)
  )
  lcd_video_instance
  (
    .clk(clk_lcd), // 125 MHz
    .reset(S_reset),
    .clk_pixel_ena(clk_pixel_ena), // if not 1 real pixel rate would be 800 kHz
    .blank(vga_blank_test),
    .hsync(vga_hsync_test),
    .vsync(vga_vsync_test),
    .color(vga_rgb_test),
    .spi_resn(oled_resn),
    .spi_clk(oled_clk),
    .spi_dc(oled_dc),
    .spi_mosi(oled_mosi)
  );
  assign oled_csn = 1;
  assign led[0] = ~vga_blank_test;
  assign led[1] = vga_hsync_test;
  assign led[2] = vga_vsync_test;
  assign led[7:3] = 0;
endmodule
