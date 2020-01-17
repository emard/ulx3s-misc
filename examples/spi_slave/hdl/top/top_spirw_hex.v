// BTN1 - MOSI data
// BTN2 - CLOCK clock
// while hoding (or not holding) BTN1 press BTN2

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

    wire ram_we;
    wire [15:0] ram_addr;
    wire [7:0] ram_di, ram_do;
    spirw_slave
    #(
        .C_sclk_capable_pin(1'b0)
    )
    spirw_slave_inst
    (
        .clk(clk),
        .csn(spi_csn),
        .sclk(wifi_gpio16),
        .mosi(sd_d[1]), // wifi_gpio4
        .miso(sd_d[2]), // wifi_gpio12
        .we(ram_we),
        .addr(ram_addr),
        .data_in(ram_do),
        .data_out(ram_di)
    );
    
    reg [7:0] ram[0:255];
    reg [7:0] R_ram_do;
    always @(posedge clk)
    begin
      if(ram_we)
        ram[ram_addr] <= ram_di;
      else
        R_ram_do <= ram[ram_addr];
    end
    assign ram_do = R_ram_do;

    localparam C_display_bits = 128;
    wire [C_display_bits-1:0] S_display;
    assign S_display[15:0] = ram_addr;
    assign S_display[23:16] = ram[0];
    assign S_display[31:24] = ram[1];
    assign S_display[39:32] = ram[2];
    
    // lower row displays HEX data, incoming from right to left
    //assign S_display[C_display_bits-1:C_display_bits-C_mosi_bits] = S_mosi;

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
