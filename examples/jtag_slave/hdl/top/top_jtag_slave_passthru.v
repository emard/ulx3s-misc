module top_jtag_slave_passthru
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,
    input  wire ftdi_ndtr, ftdi_nrts, ftdi_txd, // TCK, TMS, TDI
    output wire ftdi_rxd,  // TDO
    output wire oled_csn, oled_clk, oled_mosi, oled_dc, oled_resn,
    input  wire sd_clk, sd_cmd, // wifi_gpio 14,15
    inout  wire [3:0] sd_d, // wifi_gpio 13,12,4,2
    input  wire wifi_txd, wifi_gpio5, wifi_gpio16, wifi_gpio17,
    output wire wifi_rxd, wifi_en, wifi_gpio0
);
    localparam C_prog_release_bits = 19;
    reg [C_prog_release_bits-1:0] R_prog_release;

    wire tck, tms, tdi, tdo;
    // assign tck = ftdi_ndtr;
    // assign tms = ftdi_nrts;
    // assign tdi = ftdi_txd;
    // assign ftdi_rxd = tdo;
    
    assign ftdi_rxd = wifi_txd;
    assign wifi_rxd = ftdi_txd;
    // Programming logic
    // SERIAL  ->  ESP32
    // prog_in    prog_out
    //  1   0      1   0
    // DTR RTS -> IO0  EN
    //  1   1      1   1
    //  0   0      1   1
    //  1   0      1   0
    //  0   1      0   1
    wire [1:0] S_prog_in;
    assign S_prog_in[1] = ftdi_ndtr;
    assign S_prog_in[0] = ftdi_nrts;
    wire [1:0] S_prog_out;
    assign S_prog_out = S_prog_in == 2'b00 ? 2'b11 : S_prog_in;
    assign wifi_gpio0 = S_prog_out[1] & btn[0];
    // assign wifi_gpio0 = R_prog_release[C_prog_release_bits-1] ? btn[0] : S_prog_out[1] & btn[0];
    assign sd_d[0] = R_prog_release[C_prog_release_bits-1] ? 1'bz : S_prog_out[1]; // sd_d[0] = wifi_gpio2 together with wifi_gpio0 to 0
    // assign wifi_en = R_prog_release[C_prog_release_bits-1] ? 1'b1 : S_prog_out[0];
    assign wifi_en = S_prog_out[0];
    
    assign led[7] = wifi_en;
    assign led[5] = wifi_gpio5;
    // assign led[0] = sd_d[0];

    // programming release counter
    reg [1:0] R_prog_in, R_prog_in_prev;
    always @(posedge clk_25mhz)
    begin
        R_prog_in_prev <= R_prog_in;
        R_prog_in <= S_prog_in;
        if((R_prog_in == 2'b10 /* || R_prog_in == 2'b01 */) && R_prog_in_prev != 2'b10)
          R_prog_release <= 0;
        else
          if(R_prog_release[C_prog_release_bits-1] == 1'b0)
            R_prog_release <= R_prog_release + 1;
    end

    /*
    wire clk_50MHz;
    clk_25_50_25
    clk_25_50_25_inst
    (
      .clki(clk_25mhz),
      .clko(clk_50MHz)
    );
    */
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
