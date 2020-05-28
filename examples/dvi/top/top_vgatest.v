module top_vgatest
#(
  // C_mode
  // 0:  640x480  @60Hz
  // 1:  720x576  @50Hz
  // 2:  800x600  @60Hz
  // 3: 1024x768  @60Hz
  // 4: 1280x1024 @60Hz
  // 5: 1920x1080 @30Hz
  parameter C_mode = 0,
  parameter C_ddr  = 1 // 0:SDR 1:DDR
)
(
  input        clk_25mhz,
  input  [6:0] btn,
  output [7:0] led,
  output [3:0] gpdi_dp,
  output       wifi_gpio0
);

  // wifi_gpio0=1 keeps board from rebooting
  // hold btn0 to let ESP32 take control over the board
  assign wifi_gpio0 = btn[0];

  // clock generator
  wire clk_locked;
  wire [3:0] clocks;
  wire clk_shift = clocks[0];
  wire clk_pixel = clocks[1];
  wire [7:0] vga_r, vga_g, vga_b;
  wire vga_hsync, vga_vsync, vga_blank;
  generate
    if(C_mode == 0) // 640x480@60Hz
    begin
      ecp5pll
      #(
          .in_hz( 25000000),
        .out0_hz(125000000*(C_ddr?1:2)),
        .out1_hz( 25000000)
      )
      ecp5pll_inst
      (
        .clk_i(clk_25mhz),
        .clk_o(clocks),
        .locked(clk_locked)
      );
      // VGA signal generator
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
    end
    if(C_mode == 1) // 720x576@50Hz
    begin
      ecp5pll
      #(
          .in_hz( 25000000),
        .out0_hz(135000000*(C_ddr?1:2)),
        .out1_hz( 27000000)
      )
      ecp5pll_inst
      (
        .clk_i(clk_25mhz),
        .clk_o(clocks),
        .locked(clk_locked)
      );
      // VGA signal generator
      vga
      #(
        // https://github.com/Xilinx/embeddedsw/blob/master/XilinxProcessorIPLib/drivers/video_common/src/xvidc_timings_table.c
        .C_resolution_x(720),
        .C_hsync_front_porch(12),
        .C_hsync_pulse(64),
        .C_hsync_back_porch(68),
        .C_resolution_y(576),
        .C_vsync_front_porch(5),
        .C_vsync_pulse(5),
        .C_vsync_back_porch(39),
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
    end
    if(C_mode == 2) // 800x600@60Hz
    begin
      ecp5pll
      #(
          .in_hz( 25000000),
        .out0_hz(200000000*(C_ddr?1:2)),
        .out1_hz( 40000000)
      )
      ecp5pll_inst
      (
        .clk_i(clk_25mhz),
        .clk_o(clocks),
        .locked(clk_locked)
      );
      // VGA signal generator
      vga
      #(
        // https://github.com/Xilinx/embeddedsw/blob/master/XilinxProcessorIPLib/drivers/video_common/src/xvidc_timings_table.c
        .C_resolution_x(800),
        .C_hsync_front_porch(32),
        .C_hsync_pulse(80),
        .C_hsync_back_porch(112),
        .C_resolution_y(600),
        .C_vsync_front_porch(3),
        .C_vsync_pulse(5),
        .C_vsync_back_porch(43),
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
    end
    if(C_mode == 3) // 1024x768@60Hz
    begin
      ecp5pll
      #(
          .in_hz( 25000000),
        .out0_hz(325000000*(C_ddr?1:2)),
        .out1_hz( 65000000)
      )
      ecp5pll_inst
      (
        .clk_i(clk_25mhz),
        .clk_o(clocks),
        .locked(clk_locked)
      );
      // VGA signal generator
      vga
      #(
        .C_resolution_x(1024),
        .C_hsync_front_porch(16),
        .C_hsync_pulse(96),
        .C_hsync_back_porch(44),
        .C_resolution_y(768),
        .C_vsync_front_porch(10),
        .C_vsync_pulse(2),
        .C_vsync_back_porch(31),
        .C_bits_x(11),
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
    end
    if(C_mode == 4) // 1280x1024@60Hz
    begin
      ecp5pll
      #(
          .in_hz( 25000000),
        .out0_hz(375000000*(C_ddr?1:2)),
        .out1_hz( 75000000)
      )
      ecp5pll_inst
      (
        .clk_i(clk_25mhz),
        .clk_o(clocks),
        .locked(clk_locked)
      );
      // VGA signal generator
      vga
      #(
        .C_resolution_x(1280),
        .C_hsync_front_porch(30),
        .C_hsync_pulse(64),
        .C_hsync_back_porch(60),
        .C_resolution_y(1024),
        .C_vsync_front_porch(3),
        .C_vsync_pulse(5),
        .C_vsync_back_porch(10),
        .C_bits_x(11),
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
    end
    if(C_mode == 5) // 1920x1080@30Hz
    begin
      ecp5pll
      #(
          .in_hz( 25000000),
        .out0_hz(375000000*(C_ddr?1:2)),
        .out1_hz( 75000000)
      )
      ecp5pll_inst
      (
        .clk_i(clk_25mhz),
        .clk_o(clocks),
        .locked(clk_locked)
      );
      // VGA signal generator
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
    end
  endgenerate

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
  assign led[7:6] = countblink[7:6];
  
  assign led[0] = vga_vsync;
  assign led[1] = vga_hsync;
  assign led[2] = vga_blank;

  // VGA to digital video converter
  wire [1:0] tmds[3:0];
  vga2dvid
  #(
    .C_ddr(C_ddr?1'b1:1'b0),
    .C_shift_clock_synchronizer(1'b1)
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
    .out_clock(tmds[3]),
    .out_red(tmds[2]),
    .out_green(tmds[1]),
    .out_blue(tmds[0])
  );

  generate
    if(C_ddr)
    begin
      // vendor specific DDR modules
      // convert SDR 2-bit input to DDR clocked 1-bit output (single-ended)
      // onboard GPDI
      ODDRX1F ddr0_clock (.D0(tmds[3][0]), .D1(tmds[3][1]), .Q(gpdi_dp[3]), .SCLK(clk_shift), .RST(0));
      ODDRX1F ddr0_red   (.D0(tmds[2][0]), .D1(tmds[2][1]), .Q(gpdi_dp[2]), .SCLK(clk_shift), .RST(0));
      ODDRX1F ddr0_green (.D0(tmds[1][0]), .D1(tmds[1][1]), .Q(gpdi_dp[1]), .SCLK(clk_shift), .RST(0));
      ODDRX1F ddr0_blue  (.D0(tmds[0][0]), .D1(tmds[0][1]), .Q(gpdi_dp[0]), .SCLK(clk_shift), .RST(0));
    end
    else
    begin
      assign gpdi_dp[3] = tmds[3][0];
      assign gpdi_dp[2] = tmds[2][0];
      assign gpdi_dp[1] = tmds[1][0];
      assign gpdi_dp[0] = tmds[0][0];
    end
  endgenerate

/*
  // external GPDI
  ODDRX1F ddr1_clock (.D0(tmds[3][0]), .D1(tmds[3][1]), .Q(gp[12]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr1_red   (.D0(tmds[2][0]), .D1(tmds[2][1]), .Q(gp[11]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr1_green (.D0(tmds[1][0]), .D1(tmds[1][1]), .Q(gp[10]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr1_blue  (.D0(tmds[0][0]), .D1(tmds[0][1]), .Q(gp[ 9]), .SCLK(clk_shift), .RST(0));
*/
endmodule
