`default_nettype none
// passthru for st7789
module top_st7789_spi_slave
#(  // choose one of
  parameter c_lcd = 1, // spi to display
  parameter c_hex = 0  // see RAM in HEX
)
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
  input  wire ftdi_txd,
  output wire ftdi_rxd,
  inout  wire sd_clk, sd_cmd,
  inout  wire [3:0] sd_d,
  output wire wifi_en,
  input  wire wifi_txd,
  output wire wifi_rxd,
  input  wire wifi_gpio17,
  input  wire wifi_gpio16,
  //output wire wifi_gpio5,
  output wire wifi_gpio0
);
  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(125*1000000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks)
  );
  wire   clk = clocks[0];

  assign wifi_gpio0 = btn[0];
  assign wifi_en    = 1;

  // passthru to ESP32 micropython serial console
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;

  //assign sd_d[1]    = 1'bz; // wifi_gpio4
  //assign sd_d[2]    = 1'bz; // wifi_gpio12
  //assign sd_d[3]    = 1; // SD card inactive at SPI bus

  // wifi aliasing for shared pins
  wire  wifi_gpio26  = gp[11];
  wire  wifi_gpio25  = gn[11];
  wire  wifi_gpio32, wifi_gpio33, wifi_gpio34, wifi_gpio35; // FPGA OUT, ESP32 IN
  assign gn[12]      = wifi_gpio32;
  assign gp[12]      = wifi_gpio33;
  assign gn[13]      = wifi_gpio34;
  assign gp[13]      = wifi_gpio35;

  // aliasing for SPI
  // ESP32 micropython pinout should match this
  wire   spi_csn     = wifi_gpio16;
  wire   spi_clk     = wifi_gpio17;
  wire   spi_mosi    = wifi_gpio25;
  wire   spi_miso;
  assign wifi_gpio33 = spi_miso;

  //assign oled_csn = 1; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)
  //assign oled_csn = w_oled_csn; // 8-pin ST7789: oled_csn is connected to CSn
  //assign oled_dc    = lcd_dc;
  //assign oled_resn  = lcd_resn;
  //assign oled_mosi  = lcd_mosi;
  //assign oled_clk   = lcd_clk;

  assign led[4:0] = {oled_csn,oled_dc,oled_resn,oled_mosi,oled_clk};
  assign led[7:5] = 0;

  wire ram_wr;
  wire [31:0] ram_addr;
  wire [7:0] ram_di, ram_do;
  spirw_slave_v
  #(
      .c_addr_bits(32),
      .c_sclk_capable_pin(1'b0)
  )
  spirw_slave_v_inst
  (
      .clk(clk),
      .csn(spi_csn),
      .sclk(spi_clk),
      .mosi(spi_mosi),
      .miso(spi_miso),
      .wr(ram_wr),
      .addr(ram_addr),
      .data_in(ram_do),
      .data_out(ram_di)
  );

  generate
  if(c_lcd)

  wire busy;
  reg R_busy;
  
  reg [15:0] R_x, R_y, R_color;
  always @(posedge clk)
  begin
    R_busy <= busy;
    if (R_busy & ~busy) begin // falling edge of busy
      if (R_x != 239)
        R_x <= R_x+1;
      else
      begin
        R_x <= 0;
        R_color <= R_color+1;
        if (R_y != 319)
          R_y <= R_y+1;
        else
        begin
          R_y <= 80;
        end
      end
    end
  end

  wire pixel_plot, pixel_busy;
  wire [15:0] pixel_x, pixel_y, pixel_color;
  draw_line
  draw_line_inst
  (
    .clk(clk),
    .plot(~btn[1]),
    .busy(busy),
    .x0(R_x),
    .y0(R_y),
    .x1(R_x),
    .y1(R_y),
    .color(R_color),
    .pixel_plot(pixel_plot),
    .pixel_busy(pixel_busy),
    .pixel_x(pixel_x),
    .pixel_y(pixel_y),
    .pixel_color(pixel_color)
  );

  wire w_oled_csn;
  lcd_pixel
  #(
    .c_clk_mhz(125),
    .c_init_file("st7789_linit_pixels.mem"),
    .c_clk_phase(0),
    .c_clk_polarity(1),
    .c_pixel_start(24),
    .c_init_size(40)
  )
  lcd_pixel_inst
  (
    .clk(clk),
    .reset(~btn[0]),
    .plot(pixel_plot),
    .busy(pixel_busy),
    .x(R_x),
    .y(R_y),
    .color(R_color),
    .spi_clk(oled_clk),
    .spi_mosi(oled_mosi),
    .spi_dc(oled_dc),
    .spi_resn(oled_resn),
    .spi_csn(w_oled_csn)
  );
  assign oled_csn = 1; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)
  //assign oled_csn = w_oled_csn; // 8-pin ST7789: oled_csn is connected to CSn
  begin
  end
  if(c_hex)
  begin

  reg [7:0] ram[0:255];
  reg [7:0] R_ram_do;
  always @(posedge clk)
  begin
    if(ram_wr)
      ram[ram_addr] <= ram_di;
    else
      R_ram_do <= ram[ram_addr];
  end
  assign ram_do = R_ram_do;

  localparam C_display_bits = 64;
  wire [C_display_bits-1:0] S_display;
  assign S_display[31:0] = ram_addr;
  // such RAM reading works for trellis but not for diamond
  assign S_display[39:32] = ram[255];
  assign S_display[47:40] = ram[0];
  assign S_display[55:48] = ram[1];
  assign S_display[63:56] = ram[2];

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
  assign oled_csn = 1; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)
  //assign oled_csn = w_oled_csn; // 8-pin ST7789: oled_csn is connected to CSn
  end // if(c_hex)
  endgenerate

endmodule
