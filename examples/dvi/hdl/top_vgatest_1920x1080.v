module top_vgatest_1920x1080
(
  input         clk_25mhz,
  input   [6:0] btn,
  output  [7:0] led,
  output  [3:0] gpdi_dp,
  output [27:0] gp,
  output        wifi_gpio0
);
    parameter C_ddr = 1'b1; // 0:SDR 1:DDR

    // wifi_gpio0=1 keeps board from rebooting
    // hold btn0 to let ESP32 take control over the board
    assign wifi_gpio0 = btn[0];

    // clock generator
    wire clk_shift, clk_pixel, clk_locked;
    clk_25_shift_pixel
    clock_instance
    (
      .clki(clk_25mhz),
      .clko(clk_shift),
      .clks1(clk_pixel),
      .locked(clk_locked)
    );
    
    // LED blinky
    localparam counter_width = 28;
    wire [7:0] countblink;
    blink
    #(
      .bits(counter_width)
    )
    blink_instance
    (
      .clk(clk_pixel),
      .led(countblink)
    );
    assign led[0] = btn[1];
    assign led[7:1] = countblink[7:1];

    // VGA signal generator
    wire [7:0] vga_r, vga_g, vga_b;
    wire vga_hsync, vga_vsync, vga_blank;
    vga
    #(
      // https://github.com/Xilinx/embeddedsw/blob/master/XilinxProcessorIPLib/drivers/video_common/src/xvidc_timings_table.c
      .C_resolution_x(1920),
      .C_hsync_front_porch(88),
      .C_hsync_pulse(44),
      //.C_hsync_back_porch(148), // as specified by xvidc_timings
      .C_hsync_back_porch(133), // our adjustment for 75 MHz pixel clock
      .C_resolution_y(1080),
      .C_vsync_front_porch(4),
      .C_vsync_pulse(5),
      //.C_vsync_back_porch(36), // as specified by xvidc_timings
      .C_vsync_back_porch(46), // our adjustment for 75 MHz pixel clock
      .C_bits_x(12),
      .C_bits_y(11)
    )
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

    // VGA to digital video converter
    wire [1:0] tmds[3:0];
    vga2dvid
    #(
      .C_shift_clock_synchronizer(1'b1),
      .C_parallel(1'b0),
      .C_ddr(C_ddr)
    )
    vga2dvid_instance
    (
      .clk_pixel(clk_pixel),
      .clk_shift(clk_shift),
      .in_red(vga_r),
      .in_green(vga_g),
      .in_blue(vga_b),
      .in_hsync(~vga_hsync),
      .in_vsync(~vga_vsync),
      .in_blank(vga_blank),
      .out_clock(tmds[3]),
      .out_red(tmds[2]),
      .out_green(tmds[1]),
      .out_blue(tmds[0])
    );

    // output TMDS SDR/DDR data to fake differential lanes
    /*
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
      .out_p(gpdi_dp),
      .out_n(gpdi_dn)
    );
    */

  // vendor specific DDR modules
  // convert SDR 2-bit input to DDR clocked 1-bit output (single-ended)
  // onboard GPDI

  ODDRX1F ddr0_clock (.D0(tmds[3][0]), .D1(tmds[3][1]), .Q(gpdi_dp[3]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr0_red   (.D0(tmds[2][0]), .D1(tmds[2][1]), .Q(gpdi_dp[2]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr0_green (.D0(tmds[1][0]), .D1(tmds[1][1]), .Q(gpdi_dp[1]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr0_blue  (.D0(tmds[0][0]), .D1(tmds[0][1]), .Q(gpdi_dp[0]), .SCLK(clk_shift), .RST(0));

  // external GPDI
  ODDRX1F ddr1_clock (.D0(tmds[3][0]), .D1(tmds[3][1]), .Q(gp[12]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr1_red   (.D0(tmds[2][0]), .D1(tmds[2][1]), .Q(gp[11]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr1_green (.D0(tmds[1][0]), .D1(tmds[1][1]), .Q(gp[10]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr1_blue  (.D0(tmds[0][0]), .D1(tmds[0][1]), .Q(gp[ 9]), .SCLK(clk_shift), .RST(0));

endmodule
