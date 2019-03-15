module top (
    input wire clk_25mhz,
    input wire [6:0] btn,
    output wire [7:0] led,
    output wire oled_csn,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire oled_resn,
    output wire wifi_gpio0
);
    assign wifi_gpio0 = btn[0];

    wire clk;
    wire locked;
    pll pll(
        .clki(clk_25mhz),
        .clko(clk), // 12.5 MHz
        .locked(locked)
    );

    wire [7:0] x;
    wire [5:0] y;
    wire [7:0] color;

    oled_init
    oled_init_inst(
        .clk(clk),
        .debug(led),
        .oled_csn(oled_csn),
        .oled_clk(oled_clk),
        .oled_mosi(oled_mosi),
        .oled_dc(oled_dc),
        .oled_resn(oled_resn)
    );

endmodule
