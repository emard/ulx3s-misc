module top_spi_hex
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,
    output wire oled_csn,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire oled_resn,
    input  wire wifi_gpio5,
    output wire wifi_gpio0
);
    assign wifi_gpio0 = btn[0];
    
    assign led[4] = wifi_gpio5;

    wire clk, locked;
    pll
    pll_inst
    (
        .clki(clk_25mhz),
        .clko(clk), // 12.5 MHz
        .locked(locked)
    );

    localparam C_bits_width = 64;
    wire [C_bits_width-1:0] S_display; // something to display
    spi_slave
    #(
        .C_data_len(C_bits_width)
    )
    spi_slave_inst
    (
        .clk(btn[2]),
        .csn(1'b0),
        .mosi(btn[1]),
        .data(S_display)
    );

    wire [6:0] x;
    wire [5:0] y;
    wire next_pixel;
    wire [7:0] color;
    
    hex_decoder
    #(
        .C_data_len(C_bits_width),
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
