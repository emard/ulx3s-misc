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

  wire [6:0] btnd, btnr, btnf;
  btn_debounce
  #(
    .bits(16),
    .btns(7)
  )
  btn_debounce_i
  (
    .clk(clk),
    .btn(btn),
    .debounce(btnd),
    .rising(btnr),
    .falling(btnf)
  );

  reg [2:0] cursor = 7;
  always @(posedge clk)
  begin
    if (btnr[6]) begin
      //if (cursor != 0)
        cursor <= cursor - 1;
    end else if (btnr[5]) begin
      //if (cursor != 6)
        cursor <= cursor + 1;
    end
  end

  reg r_wr;
  reg [7:0] r_data;

  wire tick;
  wire [63:0] datetime;
  mcp7940n
  #(
    .c_clk_mhz(25),
    .c_slow_bits(18)
  )
  mcp7940n_inst
  (
    .clk(clk),
    .reset(~btn[0]),
    .wr(r_wr),
    .addr(cursor),
    .data(r_data),
    .tick(tick),
    .datetime_o(datetime[55:0]),
    .sda(gpdi_sda),
    .scl(gpdi_scl)
  );
  
  reg [7:0] R_values[8:7];
  wire [63:0] w_datetime;
/*
  always @(posedge clk)
  begin
    if (tick) begin
      w_datetime[55:0] <= datetime[55:0];
    end
  end
*/
  wire [63:0] cursor_marker;
  //wire [7:0] value[0:7];
  generate
    genvar i;
    for (i = 0; i != 8; i=i+1) begin
      assign cursor_marker[i*8+7:i*8] = (cursor == i ? 8'h11 : 8'h00);
      assign w_datetime[i*8+7:i*8] = R_values[i];
      always @(posedge clk) if (tick) R_values[i] <= datetime[i*8+7:i*8];
    end
  endgenerate

  wire [7:0] next_data;
  reg [7:0] current_val;
  wire [7:0] bcd_inc = current_val[3:0] == 9 ? {current_val[7:4]+1,4'h0} : current_val+1;
  wire [7:0] bcd_dec = current_val[3:0] == 0 ? {current_val[7:4]-1,4'h9} : current_val-1;
  // BCD INC/DEC
  assign next_data[6:0] = btnr[4] ? bcd_dec : bcd_inc;
  assign next_data[7] = (cursor == 0) ? 1 : 0;
  always @(posedge clk)
  begin
    current_val <= R_values[cursor];
    r_data <= next_data;
    r_wr <= btnr[3] | btnr[4];
  end

  localparam C_display_bits = 128;
  wire [C_display_bits-1:0] S_display;
  assign S_display[55:0]   = w_datetime;
  assign S_display[63:56]  = 8'h20; // 100-year fixed 20xx
  assign S_display[127:64] = cursor_marker;

  assign led = w_datetime[7:0];
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
