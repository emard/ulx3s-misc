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
  output wire wifi_gpio0
);
  assign wifi_gpio0 = btn[0];
  
  wire tck, tms, tdi, tdo;

  assign clk = clk_25mhz;

  // vendor-specfic "JTAGG" module: passthru JTAG traffic to user bitstream
  wire jtdi, jtck, jshift, jupdate, jce1, jce2, jrstn, jrti1, jrti2;
  JTAGG
  jtagg_inst
  (
    .JTDI(jtdi),       // output data
    .JTCK(jtck),       // output clock
    .JRTI2(jrti1),     // 1 if reg is selected and state is r/t idle
    .JRTI1(jrti2),
    .JSHIFT(jshift),   // 1 if data is shifted in
    .JUPDATE(jupdate), // 1 for 1 tck on finish shifting
    .JRSTN(jrstn),
    .JCE2(jce2),       // 1 if data shifted into this reg
    .JCE1(jce1)
  );

  localparam C_capture_bits = 64;
  wire [C_capture_bits-1:0] S_tms, S_tdi, S_tdo; // this is SPI MOSI shift register

  spi_slave
  #(
    .C_sclk_capable_pin(1'b0),
    .C_data_len(C_capture_bits)
  )
  spi_slave_tdi_inst
  (
    .clk(clk),
    .csn(1'b0),
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
    .c_font_file("oled_font.mem"),
    .c_color_bits(c_color_bits)
  )
  hex_decoder_inst
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
  lcd_video_inst
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

endmodule
