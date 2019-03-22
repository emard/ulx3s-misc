// BTN1 - MOSI data
// BTN2 - CLOCK clock
// while hoding (or not holding) BTN1 press BTN2

/*
ft232r_tck_num DTR ftdi_ndtr
ft232r_tms_num RTS ftdi_nrts
ft232r_tdi_num TXD ftdi_txd
ft232r_tdo_num RXD ftdi_rxd
*/

module top_jtag_slave
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,
    input  wire ftdi_ndtr, // TCK
    input  wire ftdi_nrts, // TMS
    input  wire ftdi_txd,  // TDI
    output wire ftdi_rxd,  // TDO
    output wire oled_csn,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire oled_resn,
    output wire wifi_gpio0
);
    assign wifi_gpio0 = btn[0];
    
    wire tck, tms, tdi, tdo;
    assign tck = ftdi_ndtr;
    assign tms = ftdi_nrts;
    assign tdi = ftdi_txd;
    assign ftdi_rxd = tdo;
    
    wire clk, locked;
    pll
    pll_inst
    (
        .clki(clk_25mhz),
        .clko(clk), // 12.5 MHz
        .locked(locked)
    );
    
    jtag_slave
    jtag_slave_inst
    (
      .tck_pad_i(tck),
      .tms_pad_i(tms),
      .trstn_pad_i(1'b1),
      .tdi_pad_i(tdi),
      .tdo_pad_o(tdo)
    );

    localparam C_mosi_bits = 64;
    wire [C_mosi_bits-1:0] S_mosi; // this is SPI MOSI shift register
    spi_slave
    #(
        .C_sclk_capable_pin(1'b0),
        .C_data_len(C_mosi_bits)
    )
    spi_slave_mosi_inst
    (
        .clk(clk),
        .sclk(btn[2]),
        .csn(1'b0),
        .mosi(btn[1]),
        .data(S_mosi)
    );

    localparam C_display_bits = 128;
    wire [C_display_bits-1:0] S_display;
    // upper row displays binary as shifted in time, incoming from left to right
    genvar i;
    generate
      for(i = 0; i < C_mosi_bits/4; i++)
        assign S_display[C_mosi_bits-4*i-4] = S_mosi[i];
    endgenerate
    
    // lower row displays HEX data, incoming from right to left
    assign S_display[C_display_bits-1:C_display_bits-C_mosi_bits] = S_mosi;

    wire [6:0] x;
    wire [5:0] y;
    wire next_pixel;
    wire [7:0] color;

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
        .C_init_file("oled_init_xflip.mem")
    )
    oled_video_inst
    (
        .clk(clk),
        .x(x),
        .y(y),
        .next_pixel(next_pixel),
        .color(color),
        .oled_csn(oled_csn),
        .oled_clk(oled_clk),
        .oled_mosi(oled_mosi),
        .oled_dc(oled_dc),
        .oled_resn(oled_resn)
    );
endmodule
