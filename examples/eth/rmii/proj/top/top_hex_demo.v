`default_nettype none
module top_hex_demo
(
  input  wire clk_25mhz,
  input  wire [6:0] btn,
  output wire [7:0] led,
  inout  wire [27:0] gp,gn,
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
  
  // ETH RMII LAN8720 signals labelled on the PCB
  wire rmii_tx_en ; assign gn[10] = rmii_tx_en; // 0:RX 1:TX
  wire rmii_tx0   ; assign gp[10] = rmii_tx0;
  wire rmii_tx1   ; assign gn[9]  = rmii_tx1;
  wire rmii_crs   = gp[12]; // 0:IDLE 1:RX DATA VALID
  wire rmii_rx0   = gn[11];
  wire rmii_rx1   = gp[11];
  wire rmii_nint  = gn[12]; // clock 50MHz
  wire rmii_mdio  = gn[13];
  wire rmii_mdc   = gp[13];
  
  wire rmii_clk   = rmii_nint;
  assign rmii_tx_en = 0; // dont send, just sniff

  reg [1:0] R_data[0:128]; // collects data

  reg [7:0] indx;
  always @(posedge rmii_clk)
  begin
    if(rmii_crs)
    begin
      if(indx[7]==0)
      begin
        R_data[indx] <= {rmii_rx1, rmii_rx0};
        indx <= indx + 1;
      end
    end
    else
    begin
      indx <= 0;
    end
  end

  wire [255:0] R_display; // wiring to display
  generate
    genvar i;
    for(i=0; i<128; i++)
    begin
      assign R_display[i*2+1:i*2] = R_data[i];
    end
  endgenerate

  wire [7:0] x;
  wire [7:0] y;
  // for reverse screen:
  //wire [7:0] ry = 239-y;
  wire [C_color_bits-1:0] color;
  hex_decoder_v
  #(
    .c_data_len(256),
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
  //assign oled_csn = w_oled_csn | btn[1]; // BTN1 and 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)
  assign oled_csn = 1; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)
  //assign oled_csn = w_oled_csn; // 8-pin ST7789: oled_csn is connected to BLK (backlight enable pin)

endmodule
