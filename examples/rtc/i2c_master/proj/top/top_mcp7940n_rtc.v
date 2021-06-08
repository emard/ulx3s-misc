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
  output wire [3:0] gpdi_dp,
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

  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(125*1000000),                 .out0_tol_hz(0),
    .out1_hz( 25*1000000), .out1_deg(  0), .out1_tol_hz(0)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks)
  );
  wire clk_shift = clocks[0];
  wire clk_pixel = clocks[1];
  wire clk       = clocks[1];

  //wire clk = clk_25mhz;

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
  
  reg [7:0] R_values[0:7];
  wire [63:0] w_datetime;
  wire [63:0] cursor_marker;
  //wire [7:0] value[0:7];
  generate
    genvar i;
    for (i = 0; i < 8; i=i+1) begin
      assign cursor_marker[i*8+7:i*8] = (cursor == i ? 8'h11 : 8'h00);
      always @(posedge clk) if (tick) R_values[i] <= datetime[i*8+7:i*8];
      assign w_datetime[i*8+7:i*8] = R_values[i];
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
    .c_init_size(35),
    .c_clk_phase(0),
    .c_clk_polarity(1)
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

  wire vga_hsync, vga_vsync, vga_blank;
  wire [7:0] vga_r, vga_g, vga_b;
  wire [1:0] dvid_red, dvid_green, dvid_blue, dvid_clock;
  wire [15:0] dvi_color;
  wire [9:0] beam_x, beam_y;
  wire [9:0] beam_rx = 636 - beam_x;
  // HEX decoder needs reverse X-scan, few pixels adjustment for pipeline delay
  hex_decoder_v
  #(
    .c_data_len(C_display_bits),
    .c_row_bits(4), // 2**n digits per row (4*2**n bits/row) 3->32, 4->64, 5->128, 6->256
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_x_bits(8),
    .c_y_bits(5),
    .c_color_bits(16)
  )
  hex_decoder_dvi_instance
  (
    .clk(clk_pixel),
    .data(S_display),
    .x(beam_rx[9:2]),
    .y(beam_y[6:2]),
    .color(dvi_color)
  );

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

  assign vga_r = {dvi_color[15:11],dvi_color[11],dvi_color[11],dvi_color[11]};
  assign vga_g = {dvi_color[10:5],dvi_color[5],dvi_color[5]};
  assign vga_b = {dvi_color[4:0],dvi_color[0],dvi_color[0],dvi_color[0]};
  vga2dvid
  #(
    .C_ddr(1'b1),
    .C_shift_clock_synchronizer(1'b0)
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
