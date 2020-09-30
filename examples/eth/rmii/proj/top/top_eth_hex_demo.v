/*
** simple hex packet capture
** packet content will be printed from right to left
** 8 lines of 64-bits (64 bytes)
** adjust skip_bytes to see other parts of a longer packet
*/

`default_nettype none
module top_eth_hex_demo
#(
  parameter datab2n    = 9, // 2**n data bits memory size 9: 512 bits = 64 bytes
  parameter skip_bytes = 0  // skip (ignore) data from beginning of packet
)
(
  input  wire clk_25mhz,
  input  wire [6:0] btn,
  output wire [7:0] led,
  inout  wire [27:0] gp,gn,
  output wire [3:0] gpdi_dp,
  output wire oled_csn,
  output wire oled_clk,
  output wire oled_mosi,
  output wire oled_dc,
  output wire oled_resn
);
  parameter C_color_bits = 16; 

  localparam reply_len = 82;
  reg [7:0] reply[0:reply_len-1];
  initial
    $readmemh("arp_reply.mem", reply);

  // assign led = 0;

  // clock generator
  wire clk_locked;
  wire [3:0] clocks;
  wire clk = clocks[0];
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
  wire clk_shift = clocks[0];
  wire clk_pixel = clocks[1];
  
  // ETH RMII LAN8720 signals labelled on the PCB
  wire rmii_tx_en ; assign gn[10] = rmii_tx_en; // 0:RX 1:TX
  wire rmii_tx0   ; assign gp[10] = rmii_tx0;
  wire rmii_tx1   ; assign gn[9]  = rmii_tx1;
  wire rmii_crs   =        gp[12]; // 0:IDLE 1:RX DATA VALID
  wire rmii_rx0   =        gn[11];
  wire rmii_rx1   =        gp[11];
  wire rmii_nint  =        gn[12]; // clock 50MHz
  wire rmii_mdio  =        gn[13]; // bidirectional
  wire rmii_mdc   ; assign gp[13] = rmii_mdc;

  wire rmii_clk   = rmii_nint;
  assign rmii_mdc = 0; // management clock held 0

  reg [1:0] R_data[0:2**(datab2n-1)-1]; // collects data
  reg [1:0] preamble = 1; // 0:data, 1:wait 5, 2:wait non-5, 3:skip 

  reg [datab2n-1:0] indx;
  always @(posedge rmii_clk)
  begin
    if(rmii_crs)
    begin // data valid
      if(preamble==2'd1)
      begin
        if({rmii_rx1, rmii_rx0} == 2'b01) // 5-pattern
          preamble <= 2;
      end
      else if(preamble==2'd2)
      begin
        if({rmii_rx1, rmii_rx0} != 2'b01) // end of 5-pattern, D pattern
        begin
          if(skip_bytes)
          begin
            indx <= 1-4*skip_bytes; // skip further bytes
            preamble = 3;
          end
          else // nothing to skip, directly to data
          begin
            indx <= 0;
            preamble <= 0;
          end
        end
      end
      else if(preamble==2'd3) // skip some data
      begin
        if(indx == 0)
          preamble <= 0;
        else
          indx <= indx+1; // count skip
      end
      else // preamble=0, store data
      begin
        if(indx[datab2n-1]==0)
        begin
          R_data[indx[datab2n-2:0]] <= {rmii_rx1, rmii_rx0};
          indx <= indx + 1;
        end
      end
    end
    else // not data valid
    begin
      preamble <= 1;
    end
  end

  wire [2**datab2n-1:0] R_display; // wiring to display
  generate
    genvar i;
    for(i=0; i<2**(datab2n-1); i++)
      assign R_display[i*2+1:i*2] = R_data[i];
  endgenerate

   // RX LED blink
  localparam led_on = 21;
  reg [led_on:0] R_rxled, R_txled;
  always @(posedge rmii_clk)
  begin
    if(rmii_crs)
    begin
      R_rxled <= -1;
    end
    else
    begin
      if(R_rxled[led_on])
        R_rxled <= R_rxled - 1;
    end
    if(R_tx_en)
    begin
      R_txled <= -1;
    end
    else
    begin
      if(R_txled[led_on])
        R_txled <= R_txled - 1;
    end
  end

  
  wire [6:0] btn_rising;
  btn_debounce
  btn_debounce_inst
  (
    .clk(rmii_clk),
    .btn(btn),
    .rising(btn_rising)
  );

  reg [12:0] txindx=0; // 2-bit counter
  reg [7:0] R_tx;
  reg R_tx_en = 0;
  always @(posedge rmii_clk)
  begin
    if(txindx != {reply_len,2'b00})
    begin
      if(txindx[1:0]==0)
        R_tx <= reply[txindx[12:2]];
      else
        R_tx <= R_tx[7:2]; // shift
      R_tx_en <= 1;
      txindx <= txindx + 1;
    end
    else
    begin
      if(btn_rising[1])
        txindx <= 0;
      else
        R_tx_en <= 0;
    end
  end
  assign rmii_tx_en = R_tx_en;
  assign rmii_tx0 = R_tx[0];
  assign rmii_tx1 = R_tx[1];
  assign led = {R_txled[led_on], R_rxled[led_on]};

  wire [7:0] x;
  wire [7:0] y;
  // for reverse screen:
  //wire [7:0] ry = 239-y;
  wire [C_color_bits-1:0] color;
  hex_decoder_v
  #(
    .c_data_len(2**datab2n),
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

  wire [9:0] beam_x, beam_rx, beam_y;
  wire [15:0] beam_color;
  wire vga_hsync, vga_vsync, vga_blank;
  wire [7:0] vga_r, vga_g, vga_b;
  wire [1:0] dvid_red, dvid_green, dvid_blue, dvid_clock;
  assign beam_rx = 636 - beam_x;
  // HEX decoder needs reverse X-scan, few pixels adjustment for pipeline delay
  hex_decoder_v
  #(
    .c_data_len(2**datab2n),
    .c_row_bits(4), // 2**n digits per row (4*2**n bits/row) 3->32, 4->64, 5->128, 6->256
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_x_bits(8),
    .c_y_bits(6),
    .c_color_bits(16)
  )
  hex_decoder_dvi_instance
  (
    .clk(clk_pixel),
    .data(R_display),
    .x(beam_rx[9:2]),
    .y(beam_y[7:2]),
    .color(beam_color)
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

  assign vga_r = {beam_color[15:11],beam_color[11],beam_color[11],beam_color[11]};
  assign vga_g = {beam_color[10:5],beam_color[5],beam_color[5]};
  assign vga_b = {beam_color[4:0],beam_color[0],beam_color[0],beam_color[0]};
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
