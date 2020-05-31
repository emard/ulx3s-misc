module top_hex_demo
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
  wire clk = clocks[0];
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(125*1000000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(clk_locked)
  );

  reg [127:0] R_display; // something to display
  always @(posedge clk)
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
    .c_clk_mhz(125),
    .c_init_file("st7789_linit_xflip.mem"),
    .c_clk_phase(0),
    .c_clk_polarity(1),
    .c_init_size(38)
  )
  lcd_video_inst
  (
    .clk(clk),
    .reset(~btn[0]),
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
  assign oled_csn = w_oled_csn | btn[1]; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)

endmodule
