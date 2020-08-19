`default_nettype none
module top_mcp7940n_rtc
(
  input  wire clk_25mhz,
  input  wire [6:0] btn,
  output wire [7:0] led,
  inout  wire [27:0] gp,gn,
  output wire oled_csn,
  output wire oled_clk,
  output wire oled_mosi,
  output wire oled_dc,
  output wire oled_resn,
  inout  wire shutdown,
  inout  wire gpdi_sda,
  inout  wire gpdi_scl,
  input  wire ftdi_txd,
  output wire ftdi_rxd,
  inout  wire sd_clk, sd_cmd,
  inout  wire [3:0] sd_d,
  output wire wifi_en,
  input  wire wifi_txd,
  output wire wifi_rxd,
  inout  wire wifi_gpio17,
  inout  wire wifi_gpio16,
  //input  wire wifi_gpio5, // not recommended for new designs
  output wire wifi_gpio0
);
  assign wifi_gpio0 = btn[0];
  assign wifi_en    = 1;
/*
  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(  6*1000000), .out0_tol_hz(1000000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks)
  );
    wire clk = clocks[0];
*/
  wire clk = clk_25mhz;

  // passthru to ESP32 micropython serial console
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;

  wire tick;
  wire [55:0] datetime;
  mcp7940n
  #(
    .c_clk_mhz(25),
    .c_slow_bits(18)
  )
  mcp7940n_inst
  (
    .clk(clk),
    .reset(~btn[0]),
    .tick(tick),
    .datetime_o(datetime),
    .sda(gpdi_sda),
    .scl(gpdi_scl)
  );

  reg [55:0] R_datetime;
  always @(posedge clk)
  begin
    if (tick)
      R_datetime <= datetime;
  end

  localparam C_display_bits = 64;
  wire [C_display_bits-1:0] S_display;
  assign S_display[55:0]  = R_datetime;
  assign S_display[63:56] = 8'h20; // 100-year fixed 20xx
  
  assign led = R_datetime[7:0];
  //assign led = busy;

  wire [7:0] x;
  wire [7:0] y;
  wire next_pixel;

  parameter C_color_bits = 16; // 8 for ssd1331, 16 for st7789

  wire [C_color_bits-1:0] color;

  hex_decoder_v
  #(
    .c_data_len(C_display_bits),
    .c_row_bits(4),
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_color_bits(C_color_bits)
  )
  hex_decoder_v_inst
  (
    .clk(clk),
    //.en(1'b1),
    .data(S_display),
    .x(x[7:1]),
    .y(y[7:1]),
    //.next_pixel(next_pixel),
    .color(color)
  );

  // allow large combinatorial logic
  // to calculate color(x,y)
  wire next_pixel;
  reg [C_color_bits-1:0] R_color;
  always @(posedge clk)
  //if(next_pixel)
    R_color <= color;

  wire w_oled_csn;
  lcd_video
  #(
    .c_clk_mhz(25),
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
  assign oled_csn = 1; // 7-pin ST7789: ON oled_csn is connected to BLK (backlight enable pin)
  //assign oled_csn = 0; // 7-pin ST7789: OFF oled_csn is connected to BLK (backlight enable pin)
  //assign oled_csn = w_oled_csn; // 8-pin ST7789: oled_csn is connected to CSn

endmodule
