`default_nettype none
// passthru for st7789
module top_st7789
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
    input  wire ftdi_txd,
    output wire ftdi_rxd,
    inout  wire sd_clk, sd_cmd,
    inout  wire [3:0] sd_d,
    output wire wifi_en,
    input  wire wifi_txd,
    output wire wifi_rxd,
    input  wire wifi_gpio17,
    input  wire wifi_gpio16,
    //output wire wifi_gpio5,
    output wire wifi_gpio0
);
    wire   clk = clk_25mhz;
    assign wifi_gpio0 = btn[0];
    assign wifi_en    = 1;

    // passthru to ESP32 micropython serial console
    assign wifi_rxd = ftdi_txd;
    assign ftdi_rxd = wifi_txd;

    //assign sd_d[1]    = 1'bz; // wifi_gpio4
    //assign sd_d[2]    = 1'bz; // wifi_gpio12
    //assign sd_d[3]    = 1; // SD card inactive at SPI bus

    // wifi aliasing for shared pins
    wire  wifi_gpio26 = gp[11];
    wire  wifi_gpio25 = gn[11];

    wire   lcd_dc     = wifi_gpio26;
    wire   lcd_resn   = wifi_gpio16;
    wire   lcd_mosi   = wifi_gpio25;
    wire   lcd_clk    = wifi_gpio17;
    
    assign oled_csn = 1; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)
    //assign oled_csn = w_oled_csn; // 8-pin ST7789: oled_csn is connected to CSn
    assign oled_dc    = lcd_dc;
    assign oled_resn  = lcd_resn;
    assign oled_mosi  = lcd_mosi;
    assign oled_clk   = lcd_clk;

    assign led[4:0] = {oled_csn,oled_dc,oled_resn,oled_mosi,oled_clk};
    assign led[7:5] = 0;

endmodule
