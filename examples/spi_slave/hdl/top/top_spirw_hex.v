module top_spirw_hex
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,
    output wire oled_csn,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire oled_resn,
    input  wire ftdi_txd,
    output wire ftdi_rxd,
    inout  wire sd_clk, sd_cmd,
    inout  wire [3:0] sd_d,
    input  wire wifi_txd,
    output wire wifi_rxd,
    input  wire wifi_gpio16,
    input  wire wifi_gpio5,
    output wire wifi_gpio0
);
    assign wifi_gpio0 = btn[0];

    // passthru to ESP32 micropython serial console
    assign wifi_rxd = ftdi_txd;
    assign ftdi_rxd = wifi_txd;

    assign led[4] = wifi_gpio5;

    wire clk, locked;
    pll
    pll_inst
    (
        .clki(clk_25mhz),
        .clko(clk), // 12.5 MHz
        .locked(locked)
    );
    
    assign sd_d[3] = 1'bz; // FPGA pin pullup sets SD card inactive at SPI bus
    
    wire spi_csn;
    assign spi_csn = ~wifi_gpio5; // LED is used as SPI CS

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

    localparam C_display_bits = 64;
    wire [C_display_bits-1:0] S_display;
    assign S_display[15:0] = ram_addr;
    assign S_display[23:16] = ram[0];
    assign S_display[31:24] = ram[1];
    assign S_display[39:32] = ram[2];
    
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
        .c_clk_mhz(12),
        .c_init_file("st7789_linit_xflip.mem"),
        .c_init_size(110),
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
    assign oled_csn = w_oled_csn | btn[1]; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)

      end
    endgenerate

endmodule
