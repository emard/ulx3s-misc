module top_spirw_sdram_hex
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,

    output wire oled_csn,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire oled_resn,

    //  SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
    output sdram_csn,       // chip select
    output sdram_clk,       // clock to SDRAM
    output sdram_cke,       // clock enable to SDRAM	
    output sdram_rasn,      // SDRAM RAS
    output sdram_casn,      // SDRAM CAS
    output sdram_wen,       // SDRAM write-enable
    output [12:0] sdram_a,  // SDRAM address bus
    output [1:0] sdram_ba,  // SDRAM bank-address
    output [1:0] sdram_dqm, // byte select
    inout [15:0] sdram_d,   // data bus to/from SDRAM	

    input  wire ftdi_txd,
    output wire ftdi_rxd,

    inout  wire sd_clk, sd_cmd,
    inout  wire [3:0] sd_d, // wifi_gpio4=sd_d[1] wifi_gpio12=sd_d[2]

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

    wire clk, clk_sdram, locked;
    clk_25_125_125s_25_12
    clk_25_125_125s_25_12_inst
    (
        .clki_25(clk_25mhz),
        .clko_125(clk_sdram),
        .clko_125s(sdram_clk),
        .clko_12(clk), // 12.5 MHz
        .locked(locked)
    );
    
    assign sd_d[3] = 1'bz; // FPGA pin pullup sets SD card inactive at SPI bus
    
    wire spi_cs = wifi_gpio5;
    wire spi_csn = ~wifi_gpio5; // LED is used as SPI CS

    wire ram_rd, ram_wr;
    wire [15:0] ram_addr;
    wire [15:0] ram_di;
    wire [15:0] ram_do;
    spirw_slave_v
    #(
        .c_sclk_capable_pin(1'b0)
    )
    spirw_slave_v_inst
    (
        .clk(clk_sdram), // clk will work too
        .csn(spi_csn),
        .sclk(wifi_gpio16),
        .mosi(sd_d[1]), // wifi_gpio4
        .miso(sd_d[2]), // wifi_gpio12
        .rd(ram_rd),
        .wr(ram_wr),
        .addr(ram_addr),
        .data_in(ram_do[7:0]),
        .data_out(ram_di[7:0])
    );

    assign sdram_cke = 1'b1;
    wire ram_ack = ~(ram_rd|ram_wr);
    wire ram_rdy;
    sdram_pnru
    sdram_pnru_inst
    (
      .sys_clk(clk_sdram),
      .sys_rd(ram_rd),
      .sys_wr(ram_wr),
      .sys_ab(ram_addr),
      .sys_di({ram_di[7:0],ram_di[7:0]}),
      .sys_do(ram_do),
      .sys_ack(ram_ack),
      .sys_rdy(ram_rdy),

      .sdr_ab(sdram_a),
      .sdr_db(sdram_d),
      .sdr_ba(sdram_ba),
      .sdr_n_CS_WE_RAS_CAS({sdram_csn, sdram_wen, sdram_rasn, sdram_casn}),
      .sdr_dqm(sdram_dqm)
    );
    /*
    // this doesn't work properly
    sdram_pnru2
    sdram_pnru2_inst
    (
      .sys_clk(clk_sdram),
      .sys_cs(spi_cs),
      .sys_rd(ram_rd),
      .sys_wr(ram_wr),
      .sys_ab(ram_addr),
      .sys_di({ram_di[7:0],ram_di[7:0]}),
      .sys_do(ram_do),
      .sys_rdy(ram_rdy),

      .sdr_ab(sdram_a),
      .sdr_db(sdram_d),
      .sdr_ba(sdram_ba),
      .sdr_cmd({sdram_csn, sdram_wen, sdram_rasn, sdram_casn}),
      .sdr_dqm(sdram_dqm)
    );
    */
    assign led[0] = ram_rd;
    assign led[1] = ram_wr;
    assign led[5:2] = 0;
    assign led[6] = ram_rdy;
    assign led[7] = |ram_do;

    localparam C_display_bits = 64;
    wire [C_display_bits-1:0] S_display;
    assign S_display[15:0] = ram_addr;
    assign S_display[63:64-16] = sdram_a;
    
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
