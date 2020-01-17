module top_vgatest_640x480
(
  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,
  output [3:0] gpdi_dp,
  output wifi_gpio0
);
    parameter C_ddr = 1'b1; // 0:SDR 1:DDR

    // wifi_gpio0=1 keeps board from rebooting
    // hold btn0 to let ESP32 take control over the board
    assign wifi_gpio0 = btn[0];

    // clock generator
    wire clk_250MHz, clk_125MHz, clk_25MHz, clk_locked;
    clk_25_250_125_25
    clock_instance
    (
      .clki(clk_25mhz),
      .clko(clk_250MHz),
      .clks1(clk_125MHz),
      .clks2(clk_25MHz),
      .locked(clk_locked)
    );
    
    // shift clock choice SDR/DDR
    wire clk_pixel, clk_shift;
    assign clk_pixel = clk_25MHz;
    generate
      if(C_ddr == 1'b1)
        assign clk_shift = clk_125MHz;
      else
        assign clk_shift = clk_250MHz;
    endgenerate

    // VGA signal generator
    wire [7:0] vga_r, vga_g, vga_b;
    wire vga_hsync, vga_vsync, vga_blank;
    vga
    vga_instance
    (
      .clk_pixel(clk_pixel),
      .clk_pixel_ena(1'b1),
      .test_picture(1'b1), // enable test picture generation
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .vga_hsync(vga_hsync),
      .vga_vsync(vga_vsync),
      .vga_blank(vga_blank)
    );
    
    assign led[0] = vga_vsync;
    assign led[1] = vga_hsync;
    assign led[2] = vga_blank;
    
    // OSD video overlay
    wire [7:0] osd_vga_r, osd_vga_g, osd_vga_b;
    wire osd_vga_hsync, osd_vga_vsync, osd_vga_blank;
    wire [9:0] osd_x, osd_y;
    wire [7:0] osd_r, osd_g, osd_b;
    assign osd_r = 8'h50+osd_x;
    assign osd_g = 8'h30+osd_y;
    assign osd_b = 8'h20;
    osd
    osd_instance
    (
      .clk_pixel(clk_pixel),
      .clk_pixel_ena(1'b1),
      .i_r(vga_r),
      .i_g(vga_g),
      .i_b(vga_b),
      .i_hsync(vga_hsync),
      .i_vsync(vga_vsync),
      .i_blank(vga_blank),
      .o_osd_x(osd_x),
      .o_osd_y(osd_y),
      .i_osd_r(osd_r),
      .i_osd_g(osd_g),
      .i_osd_b(osd_b),
      .o_r(osd_vga_r),
      .o_g(osd_vga_g),
      .o_b(osd_vga_b),
      .o_hsync(osd_vga_hsync),
      .o_vsync(osd_vga_vsync),
      .o_blank(osd_vga_blank)
    );

    // VGA to digital video converter
    wire [1:0] tmds[3:0];
    vga2dvid
    #(
      .C_ddr(C_ddr),
      .C_shift_clock_synchronizer(1'b1)
    )
    vga2dvid_instance
    (
      .clk_pixel(clk_pixel),
      .clk_shift(clk_shift),
      .in_red(osd_vga_r),
      .in_green(osd_vga_g),
      .in_blue(osd_vga_b),
      .in_hsync(osd_vga_hsync),
      .in_vsync(osd_vga_vsync),
      .in_blank(osd_vga_blank),
      .out_clock(tmds[3]),
      .out_red(tmds[2]),
      .out_green(tmds[1]),
      .out_blue(tmds[0])
    );

    // output TMDS SDR/DDR data to fake differential lanes
    fake_differential
    #(
      .C_ddr(C_ddr)
    )
    fake_differential_instance
    (
      .clk_shift(clk_shift),
      .in_clock(tmds[3]),
      .in_red(tmds[2]),
      .in_green(tmds[1]),
      .in_blue(tmds[0]),
      .out_p(gpdi_dp)
      //.out_n(gpdi_dn)
    );

endmodule
