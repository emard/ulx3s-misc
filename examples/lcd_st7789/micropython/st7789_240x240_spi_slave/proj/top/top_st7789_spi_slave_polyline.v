`default_nettype none
// polyline demo for st7789
module top_st7789_spi_slave_polyline
#(  // choose one of
  parameter c_lcd = 1, // SPI to display
  parameter c_hex = 0  // see RAM in HEX (must comment .spi_*() from draw_polyline)
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

  wire polyline_busy;
  assign spi_busy = polyline_busy; // pass polyline_busy to ESP32

  reg [15:0] ram[0:1023]; // BUFFER
  wire [9:0] polyline_addr;
  reg [15:0] polyline_data;
  reg [7:0] R_msb;
  // polyline data max 2KB, 512 points (x,y)
  // SPI writes 8-bit, polyline reads 16-bit
  // 0x1CDD0000 MSB X0
  // 0x1CDD0001 LSB X0
  // 0x1CDD0002 MSB Y0
  // 0x1CDD0003 LSB Y0
  // 0x1CDD0004 MSB X1
  // 0x1CDD0005 LSB X1
  // 0x1CDD0006 MSB Y1
  // 0x1CDD0007 LSB Y1
  // ...
  // 0x1CDD07FF LSB Y511
  always @(posedge clk)
  begin
    if (ram_wr) begin
      if (ram_addr[31:16] == 16'h1cdd) begin
        if (ram_addr[0])
          ram[ram_addr[10:1]] <= {R_msb, ram_di};
        else
          R_msb <= ram_di;
      end
    end
    polyline_data <= ram[polyline_addr];
  end

  // write SPI byte to 
  // 0x1CDE0000 MSB color
  // 0x1CDE0001 LSB color
  // 0x1CDE0002 MSB len (in bytes)
  // 0x1CDE0003 LSB len and execute
  reg polyline_plot;
  reg [15:0] polyline_len, polyline_color; // registers
  always @(posedge clk)
  begin
    if (ram_wr) begin
      if (ram_addr[31:16] == 16'h1cde) begin // color, length and execute
        if          (ram_addr[1:0] == 2'd0) begin // MSB color
          polyline_color[15:8] <= ram_di;
        end else if (ram_addr[1:0] == 2'd1) begin // LSB color
          polyline_color[7:0] <= ram_di;
        end else if (ram_addr[1:0] == 2'd2) begin // MSB len
          polyline_len[15:8] <= ram_di;
        end else /* if (ram_addr[1:0] == 2'd3) */ begin // LSB len and execute
          polyline_len[7:0] <= ram_di;
          polyline_plot <= 1;
        end
      end
    end else begin
      polyline_plot <= 0;
    end
  end

  // ************************************************************
  generate
  if (c_lcd) begin

  wire w_oled_csn;
  
  draw_polyline
  draw_polyline_inst
  (
    .clk(clk),
    .reset(~btn[0]),
    .plot(polyline_plot), // input rising edge starts process
    .busy(polyline_busy), // output, 1 during busy
    .len(polyline_len[8:0]), // input 0-511, how many 32-bit x,y pairs in the buffer
    .addr(polyline_addr), // output addr to buffer
    .data(polyline_data), // input data from buffer, 16-bit
    .color(polyline_color), // input color, 16-bit from SPI register
    .spi_clk(oled_clk),
    .spi_mosi(oled_mosi),
    .spi_dc(oled_dc),
    .spi_resn(oled_resn),
    .spi_csn(w_oled_csn)
  );
  end
  endgenerate

  // ************************************************************
  generate
  if (c_hex) begin

  localparam C_display_bits = 64;
  wire [C_display_bits-1:0] S_display;
  //assign S_display[31:0] = ram_addr;
  // such RAM reading works for trellis but not for diamond
  //assign S_display[47:32] = polyline_len;
  assign S_display[15:0]  = polyline_addr;
  assign S_display[31:16] = polyline_data;

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
  end // if(c_hex)
  endgenerate
  // ************************************************************

  //assign oled_csn = w_oled_csn; // 8-pin ST7789: oled_csn is connected to CSn
  assign oled_csn = 1; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)

  assign led[4:0] = {oled_csn,oled_dc,oled_resn,oled_mosi,oled_clk};
  assign led[6:5] = 0;
  assign led[7]   = polyline_busy;

endmodule
