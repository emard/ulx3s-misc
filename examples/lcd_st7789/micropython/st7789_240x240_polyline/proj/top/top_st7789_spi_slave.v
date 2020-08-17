`default_nettype none
// passthru for st7789
module top_st7789_spi_slave
#(  // choose one of
  parameter c_lcd = 1, // SPI to display
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
    .out0_hz(100*1000000)
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
  wire   spi_miso, spi_busy;
  assign wifi_gpio33 = spi_miso;
  assign wifi_gpio35 = spi_busy;

  wire ram_wr, ram_rd;
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
      .rd(ram_rd),
      .addr(ram_addr),
      .data_in(ram_do),
      .data_out(ram_di)
  );

  wire w_busy;

  // ************************************************************
  generate
  if(c_lcd)

  assign spi_busy = w_busy;

  reg [7:0] ram[0:10];
  reg [7:0] R_ram_do;
  always @(posedge clk)
  begin
    if(ram_wr)
      ram[ram_addr] <= ram_di;
    //else
    //  R_ram_do <= ram[ram_addr];
  end
  //assign ram_do = R_ram_do;
  //assign ram_do = {7'd0, w_busy}; // FIXME SPI reading doesn't work

  wire [15:0] w_x0, w_y0, w_x1, w_y1, w_color;
  assign w_x0 = {ram[0],ram[1]};
  assign w_y0 = {ram[2],ram[3]};
  assign w_x1 = {ram[4],ram[5]};
  assign w_y1 = {ram[6],ram[7]};
  assign w_color = {ram[8],ram[9]};
  
  reg R_plot;
  always @(posedge clk)
  begin
    R_plot <= ram_addr[3:0] == 9 && ram_wr;
  end
  wire w_plot = R_plot;

  wire [15:0] hvline_x, hvline_y, hvline_len, hvline_color;
  wire hvline_vertical, hvline_plot, hvline_busy;

/*
  draw_polyline
  draw_polyline_inst
  (
    .clk(clk),
    .plot(w_plot), // input rising edge starts process
    .busy(w_busy), // output, 1 during busy
    .len(w_len),   // input how many data/addr in the buffer
    .addr(w_addr), // output addr to buffer
    .data(w_data), // input data from buffer - 8 or 16 bits?
    .color(w_color), // input color (from register)
    // H/V line draw hardware
    .hvline_plot(hvline_plot), // output, rising edge starts process
    .hvline_busy(hvline_busy), // input, 1 during busy
    .hvline_x(hvline_x), // output start X
    .hvline_y(hvline_y), // output start Y
    .hvline_len(hvline_len), // output length pixels in positive X or Y direction
    .hvline_vertical(hvline_vertical), // output 0:horizontal-X 1:vertical-Y
    .hvline_color(hvline_color) // output color
  );
*/

  draw_line
  draw_line_inst
  (
    .clk(clk),
    .plot(w_plot),
    .busy(w_busy),
    .x0(w_x0),
    .y0(w_y0),
    .x1(w_x1),
    .y1(w_y1),
    .color(w_color),
    .hvline_plot(hvline_plot),
    .hvline_busy(hvline_busy),
    .hvline_x(hvline_x),
    .hvline_y(hvline_y),
    .hvline_len(hvline_len),
    .hvline_vertical(hvline_vertical),
    .hvline_color(hvline_color)
  );

  wire w_oled_csn;
  lcd_hvline
  #(
    .c_clk_mhz(125),
    .c_init_file("st7789_linit_pixels.mem"),
    .c_clk_phase(0),
    .c_clk_polarity(1)
  )
  lcd_hvline_inst
  (
    .clk(clk),
    .reset(~btn[0]),
    .plot(hvline_plot),
    .busy(hvline_busy),
    .x(hvline_x),
    .y(hvline_y),
    .len(hvline_len),
    .vertical(hvline_vertical),
    .color(hvline_color),
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
  endgenerate

  // ************************************************************
  generate
  if(c_hex)
  begin

  reg [15:0] bram[0:15];
  reg [7:0] R_ram_do, R_msb;
  always @(posedge clk)
  begin
    if(ram_wr) begin
      if (ram_addr[0])
        bram[ram_addr[5:1]] <= {R_msb, ram_di};
      else
        R_msb <= ram_di;
    end else
      R_ram_do <= bram[ram_addr];
  end
  assign ram_do = R_ram_do;

  localparam C_display_bits = 64;
  wire [C_display_bits-1:0] S_display;
  assign S_display[31:0] = ram_addr;
  // such RAM reading works for trellis but not for diamond
  assign S_display[47:32] = bram[0];
  assign S_display[63:48] = bram[1];

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
  // ************************************************************

  assign led[4:0] = {oled_csn,oled_dc,oled_resn,oled_mosi,oled_clk};
  assign led[7:5] = ram_rd;

endmodule
