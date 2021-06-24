module top_hex_mul
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
  parameter C_color_bits = 16; 

  assign led = 0;

  // clock generator
  wire clk_locked;
  wire [3:0] clocks;
  wire clk  = clocks[0];
  wire clkm = clocks[1];
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(125*1000000),
    .out1_hz( 25*1000000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(clk_locked)
  );

  // signed multiplication with 54-bit result
  reg  signed [31:0] ma = 32'd39127620;
  reg  signed [31:0] mb = 32'd35792620;
  wire signed [53:0] mc = ma*mb;

  wire [6:0] btn_rising;
  btn_debounce
  btn_debounce_inst
  (
    .clk(clkm),
    .btn(btn),
    .rising(btn_rising)
  );
  always @(posedge clkm)
  begin
    if(btn_rising[3])
      ma <= ma + 1;
    else if(btn_rising[4])
      ma <= ma - 1;
    if(btn_rising[6])
      mb <= mb + 1;
    else if(btn_rising[5])
      mb <= mb - 1;
  end

  reg [127:0] R_display; // something to display
  always @(posedge clkm)
  begin
    R_display[ 63:32] <= ma;
    R_display[ 31: 0] <= mb;
    R_display[127:64] <= mc;
  end

  wire [7:0] x;
  wire [7:0] y;
  // for reverse screen:
  //wire [7:0] ry = 239-y;
  wire [C_color_bits-1:0] color;
  hex_decoder_v
  #(
    .c_data_len(128),
    .c_row_bits(4),
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_color_bits(C_color_bits)
  )
  hex_decoder_v_inst
  (
    .clk(clk),
    .data(R_display),
    .x(x[7:1]),
    .y(y[7:1]),
    .color(color)
  );

  // allow large combinatorial logic
  // to calculate color(x,y)
  wire next_pixel;
  reg [C_color_bits-1:0] R_color;
  always @(posedge clk)
    if(next_pixel)
      R_color <= color;

  wire w_oled_csn;
  lcd_video
  #(
    .c_clk_spi_mhz(125),
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
  assign oled_csn = 1; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)

endmodule
