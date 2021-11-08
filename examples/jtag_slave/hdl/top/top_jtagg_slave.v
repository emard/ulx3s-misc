`default_nettype none
module top_jtagg_slave
(
  input  wire clk_25mhz,
  input  wire [6:0] btn,
  output wire [7:0] led,
  output wire oled_csn,
  output wire oled_clk,
  output wire oled_mosi,
  output wire oled_dc,
  output wire oled_resn,
  output wire [3:0] gpdi_dp,
  output wire wifi_gpio0
);
  assign wifi_gpio0 = btn[0];
  
  wire tck, tms, tdi, tdo;

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
  wire clk_shift  = clocks[0];
  wire clk_pixel  = clocks[1];
  wire clk        = clk_pixel;

  // vendor-specfic "JTAGG" module: passthru JTAG traffic to user bitstream
  wire jtdi, jtck, jshift, jupdate, jce1, jce2, jrstn, jrti1, jrti2;
  JTAGG
  jtagg_inst
  (
    .JTDI(jtdi),       // output data
    .JTCK(jtck),       // output clock
    .JRTI1(jrti1),     // 1 if reg is selected and state is r/t idle
    .JRTI2(jrti2),
    .JSHIFT(jshift),   // 1 if data is shifted in
    .JUPDATE(jupdate), // 1 for 1 tck on finish shifting
    .JRSTN(jrstn),
    .JCE1(jce1),       // 1 if data shifted into reg selected by SIR 8 TDI (32)
    .JCE2(jce2)        // 1 if data shifted into reg selected by SIR 8 TDI (38)
  );

  localparam C_capture_bits = 64;
  wire [C_capture_bits-1:0] S_tms, S_tdi, S_tdo; // this is SPI MOSI shift register

  wire csn1 = ~(jshift & jce1); // SIR  8 TDI (32);
  spi_slave
  #(
    .C_sclk_capable_pin(1'b0),
    .C_data_len(C_capture_bits)
  )
  spi_slave_tdi_inst
  (
    .clk(clk),
    .csn(csn1),
    .sclk(~jtck), // jtck must be inverted to work properly
    .mosi(jtdi),
    .data(S_tdi)
  );

  localparam C_shift_hex_disp_left = 0; // how many bits to left-shift hex display
  localparam C_row_digits = 16; // hex digits in one row
  localparam C_display_bits = 256;
  wire [C_display_bits-1:0] S_display;
  // home position hex digit shows TAP state
  assign S_display[63:60] = 4'h0; // leftmost hex is tap state
  // upper row displays binary as shifted in time, incoming from left to right
  genvar i;
  generate
    // row 0: binary TDI
    for(i = 0; i < C_row_digits-1; i++)
      assign S_display[4*i] = S_tdi[i];
    // row 1: TMS
    for(i = 0; i < C_capture_bits-C_shift_hex_disp_left; i++)
      assign S_display[1*C_row_digits*4+C_capture_bits-1+C_shift_hex_disp_left-i] = S_tms[i];
    // row 2: TDI
    for(i = 0; i < C_capture_bits-C_shift_hex_disp_left; i++)
      assign S_display[2*C_row_digits*4+C_capture_bits-1+C_shift_hex_disp_left-i] = S_tdi[i];
    // row 3: TDO (slave response)
    for(i = 0; i < C_capture_bits-C_shift_hex_disp_left; i++)
      assign S_display[3*C_row_digits*4+C_capture_bits-1+C_shift_hex_disp_left-i] = S_tdo[i];
  endgenerate

  // lower row displays HEX data, incoming from right to left
  // assign S_display[C_display_bits-1:C_row_digits*4] = S_mosi;

  wire [7:0] x;
  wire [7:0] y;
  wire next_pixel;
  localparam c_color_bits = 16;
  wire [c_color_bits-1:0] color;

  hex_decoder_v
  #(
    .c_data_len(C_display_bits),
    .c_row_bits(4),
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_color_bits(c_color_bits)
  )
  hex_decoder_lcd_instance
  (
    .clk(clk),
    .data(S_display),
    .x(x[7:1]),
    .y(y[7:1]),
    .color(color)
  );

  // allow large combinatorial logic
  // to calculate color(x,y)
  wire next_pixel;
  reg [c_color_bits-1:0] R_color;
  always @(posedge clk)
    if(next_pixel)
      R_color <= color;

  wire w_oled_csn;
  lcd_video
  #(
    .c_clk_spi_mhz(25),
    .c_init_file("st7789_linit_xflip.mem"),
    .c_clk_phase(0),
    .c_clk_polarity(1)
  )
  lcd_video_instance
  (
    .reset(~btn[0]),
    .clk_pixel(clk),
    .clk_spi(clk),
    .x(x),
    .y(y),
    .next_pixel(next_pixel),
    .color(R_color),
    .spi_clk(oled_clk),
    .spi_mosi(oled_mosi),
    .spi_dc(oled_dc),
    .spi_resn(oled_resn),
    .spi_csn(w_oled_csn)
  );
  assign oled_csn = w_oled_csn | ~btn[1]; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)

  wire [15:0] color_vga;
  wire [9:0] beam_x, beam_rx, beam_y;
  assign beam_rx = 636 - beam_x;
  // HEX decoder needs reverse X-scan, few pixels adjustment for pipeline delay
  hex_decoder_v
  #(
    .c_data_len(C_display_bits),
    .c_row_bits(4), // 2**n digits per row (4*2**n bits/row) 3->32, 4->64, 5->128, 6->256
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_color_bits(16)
  )
  hex_decoder_dvi_instance
  (
    .clk(clk),
    .data(S_display),
    .x(beam_rx[9:2]),
    .y(beam_y[9:2]),
    .color(color_vga)
  );

  wire vga_hsync, vga_vsync, vga_blank;
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

  wire [7:0] vga_r, vga_g, vga_b;
  wire [1:0] dvid_red, dvid_green, dvid_blue, dvid_clock;

  assign vga_r = {color_vga[15:11],color_vga[11],color_vga[11],color_vga[11]};
  assign vga_g = {color_vga[10:5],color_vga[5],color_vga[5]};
  assign vga_b = {color_vga[4:0],color_vga[0],color_vga[0],color_vga[0]};
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

