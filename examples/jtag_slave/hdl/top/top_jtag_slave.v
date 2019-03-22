// BTN1 - MOSI data
// BTN2 - CLOCK clock
// while hoding (or not holding) BTN1 press BTN2

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

    assign clk = clk_25mhz;

    jtag_slave_clk
    jtag_slave_clk_inst
    (
      .clk(clk),
      .tck_pad_i(tck),
      .tms_pad_i(tms),
      .trstn_pad_i(1'b1),
      .tdi_pad_i(tdi),
      .tdo_pad_o(tdo)
    );

    localparam C_capture_bits = 64;
    wire [C_capture_bits-1:0] S_tms, S_tdi, S_tdo; // this is SPI MOSI shift register

    spi_slave
    #(
      .C_sclk_capable_pin(1'b0),
      .C_data_len(C_capture_bits)
    )
    spi_slave_tms_inst
    (
      .clk(clk),
      .csn(1'b0),
      .sclk(tck),
      .mosi(tms),
      .data(S_tms)
    );

    spi_slave
    #(
      .C_sclk_capable_pin(1'b0),
      .C_data_len(C_capture_bits)
    )
    spi_slave_tdi_inst
    (
      .clk(clk),
      .csn(1'b0),
      .sclk(tck),
      .mosi(tdi),
      .data(S_tdi)
    );

    spi_slave
    #(
      .C_sclk_capable_pin(1'b0),
      .C_data_len(C_capture_bits)
    )
    spi_slave_tdo_inst
    (
      .clk(clk),
      .csn(1'b0),
      .sclk(tck),
      .mosi(tdo),
      .data(S_tdo)
    );

    localparam C_shift_hex_disp_left = 2; // how many bits to left-shift hex display 
    localparam C_row_digits = 16; // hex digits in one row
    localparam C_display_bits = 256;
    wire [C_display_bits-1:0] S_display;
    // upper row displays binary as shifted in time, incoming from left to right
    genvar i;
    generate
      // row 0: binary TDI
      for(i = 0; i < C_row_digits; i++)
        assign S_display[4*i] = S_tdi[i];
      // row 1: TMS
      for(i = 0; i < C_capture_bits-C_shift_hex_disp_left; i++)
        assign S_display[1*C_row_digits*4+C_capture_bits-1+C_shift_hex_disp_left-i] = S_tms[i];
      // row 2: TDI
      for(i = 0; i < C_capture_bits-C_shift_hex_disp_left; i++)
        assign S_display[2*C_row_digits*4+C_capture_bits-1+C_shift_hex_disp_left-i] = S_tdi[i];
      // row 3: TDO (slave response)
      for(i = 0; i < C_capture_bits-C_shift_hex_disp_left; i++)
        assign S_display[3*C_row_digits*4+C_capture_bits-1+C_shift_hex_disp_left-i] = S_tdo[i];
    endgenerate

    // lower row displays HEX data, incoming from right to left
    // assign S_display[C_display_bits-1:C_row_digits*4] = S_mosi;

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
