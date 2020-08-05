`default_nettype none
module top_i2c_bridge
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
    output wire shutdown,
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
    output wire wifi_gpio5,
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

    wire   eink_busy;

    assign sd_clk     = 1'bz; // wifi_gpio14
    assign sd_cmd     = 1'bz; // wifi_gpio15
    //assign sd_d[0]    = 1'bz; // wifi_gpio2
    assign sd_d[1]    = 1'bz; // wifi_gpio4
    assign sd_d[2]    = 1'bz; // wifi_gpio12
    assign sd_d[3]    = 1;    // SD card inactive at SPI bus
    
    reg eink_dc, eink_sdi, eink_cs, eink_clk, eink_busy;
    always @(posedge clk)
    begin
      eink_dc   <= gp[11];  // wifi_gpio26
      eink_sdi  <= gn[11];  // wifi_gpio25
      eink_cs   <= sd_cmd;  // wifi_gpio15
      eink_clk  <= sd_clk;  // wifi_gpio14
      eink_busy <= gp[4];   // wifi_gpio5
    end
    assign gp[0]      = eink_dc;
    assign gp[1]      = eink_sdi;
    assign gp[2]      = eink_cs;
    assign gp[3]      = eink_clk;
    assign wifi_gpio5 = eink_busy;

    // passthru to ESP32 micropython serial console
    assign wifi_rxd = ftdi_txd;
    assign ftdi_rxd = wifi_txd;

    // i2c bridge
    // slow clock enable pulse 2.77 MHz
    localparam bridge_clk_div = 3; // div = 1+2^n, 25/9=2.77 MHz
    reg [bridge_clk_div:0] bridge_cnt;
    always @(posedge clk) // 25 MHz
    begin
      if(bridge_cnt[bridge_clk_div])
        bridge_cnt <= 0;
      else
        bridge_cnt <= bridge_cnt + 1;
    end
    wire clk_bridge_en = bridge_cnt[bridge_clk_div];

    wire [1:0] i2c_sda_i = {gpdi_sda, wifi_gpio16};
    wire [1:0] i2c_sda_t;
    i2c_bridge i2c_sda_bridge_i
    (
      .clk(clk),
      .clk_en(clk_bridge_en),
      .i(i2c_sda_i),
      .t(i2c_sda_t)
    );
    assign gpdi_sda    = i2c_sda_t[1] ? 1'bz : 1'b0;
    assign wifi_gpio16 = i2c_sda_t[0] ? 1'bz : 1'b0;

    wire [1:0] i2c_scl_i = {gpdi_scl, wifi_gpio17};
    wire [1:0] i2c_scl_t;
    i2c_bridge i2c_scl_bridge_i
    (
      .clk(clk),
      .clk_en(clk_bridge_en),
      .i(i2c_scl_i),
      .t(i2c_scl_t)
    );
    assign gpdi_scl    = i2c_scl_t[1] ? 1'bz : 1'b0;
    assign wifi_gpio17 = i2c_scl_t[0] ? 1'bz : 1'b0;

    assign led[4:0] = {eink_busy,eink_clk,eink_cs,eink_sdi,eink_dc};
    assign led[5]   = 0;
    assign led[7:6] = {gpdi_sda,gpdi_scl};

/*
    wire ram_wr;
    wire [15:0] ram_addr;
    wire [7:0] ram_di, ram_do;
    spirw_slave_v
    #(
//        .c_addr_bits(16),
        .c_sclk_capable_pin(1'b0)
    )
    spirw_slave_v_inst
    (
        .clk(clk),
        .csn(spi_csn),
        .sclk(wifi_gpio16),
        .mosi(sd_d[1]), // wifi_gpio4
        .miso(sd_d[2]), // wifi_gpio12
        .wr(ram_wr),
        .addr(ram_addr),
        .data_in(ram_do),
        .data_out(ram_di)
    );
    
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
*/

    localparam C_display_bits = 64;
    wire [C_display_bits-1:0] S_display;
    //assign S_display[15:0] = ram_addr;
    //assign S_display[23:16] = ram[0];
    //assign S_display[31:24] = ram[1];
    //assign S_display[39:32] = ram[2];

    wire [7:0] x;
    wire [7:0] y;
    wire next_pixel;

    parameter C_color_bits = 16; // 8 for ssd1331, 16 for st7789

    wire [C_color_bits-1:0] color;

    generate
      if(0)
      begin // ssd1331 only
    hex_decoder
    #(
        .C_data_len(C_display_bits),
        .C_font_file("oled_font.mem")
    )
    hex_decoder_inst
    (
        .clk(clk),
        .en(1'b1),
        .data(S_display),
        .x(x),
        .y(y),
        .next_pixel(next_pixel),
        .color(color)
    );

    oled_video
    #(
        .c_init_file("oled_init_xflip.mem")
    )
    oled_video_inst
    (
        .clk(clk),
        .x(x),
        .y(y),
        .next_pixel(next_pixel),
        .color(color),
        .spi_csn(oled_csn),
        .spi_clk(oled_clk),
        .spi_mosi(oled_mosi),
        .spi_dc(oled_dc),
        .spi_resn(oled_resn)
    );
      end
      if(1)
      begin // lcd st7789 universal, can drive others
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
    //assign oled_csn = 1; // 7-pin ST7789: ON oled_csn is connected to BLK (backlight enable pin)
    assign oled_csn = 0; // 7-pin ST7789: OFF oled_csn is connected to BLK (backlight enable pin)
    //assign oled_csn = w_oled_csn; // 8-pin ST7789: oled_csn is connected to CSn

      end
    endgenerate

endmodule
