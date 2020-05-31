module top_hex_640x480
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
  wire clk_locked;
  wire [3:0] clocks;
  wire clk_shift = clocks[0];
  wire clk_pixel = clocks[1];
  ecp5pll
  #(
      .in_hz(25*1000000),
    .out0_hz(25*5000000*(C_ddr?1:2)),
    .out1_hz(25*1000000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(clk_locked)
  );

  parameter C_bits = 256;
  reg [C_bits-1:0] R_display; // something to display
  always @(posedge clk_25mhz)
  begin
    R_display[0] <= btn[0];
    R_display[4] <= btn[1];
    R_display[8] <= btn[2];
    R_display[12] <= btn[3];
    R_display[16] <= btn[4];
    R_display[20] <= btn[5];
    R_display[24] <= btn[6];
    R_display[58:52] <= btn;
    R_display[127:64] <= R_display[127:64] + 1; // shown in next OLED row
    R_display[31+128:128] <= R_display[31+128:128] + 1; // shown in next OLED row
  end

  parameter C_color_bits = 16; 
  wire [9:0] x;
  wire [9:0] y;
  // for reverse screen:
  wire [9:0] rx = 636-x;
  wire [C_color_bits-1:0] color;
  hex_decoder_v
  #(
    .c_data_len(C_bits),
    .c_row_bits(5), // 2**n digits per row (4*2**n bits/row) 3->32, 4->64, 5->128, 6->256 
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_x_bits(8),
    .c_y_bits(4),
    .c_color_bits(C_color_bits)
  )
  hex_decoder_v_inst
  (
    .clk(clk_pixel),
    .data(R_display),
    .x(rx[9:2]),
    .y(y[5:2]),
    .color(color)
  );

  // VGA signal generator
  wire [7:0] vga_r, vga_g, vga_b;
  assign vga_r = {color[15:11],color[11],color[11],color[11]};
  assign vga_g = {color[10:5],color[5],color[5]};
  assign vga_b = {color[4:0],color[0],color[0],color[0]};
  wire vga_hsync, vga_vsync, vga_blank;
  vga
  vga_instance
  (
    .clk_pixel(clk_pixel),
    .clk_pixel_ena(1'b1),
    .test_picture(1'b0), // enable test picture generation
    .beam_x(x),
    .beam_y(y),
    //.vga_r(vga_r),
    //.vga_g(vga_g),
    //.vga_b(vga_b),
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .vga_blank(vga_blank)
  );
  
  assign led[0] = vga_vsync;
  assign led[1] = vga_hsync;
  assign led[2] = vga_blank;

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

endmodule
