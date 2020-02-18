module top_checkered
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,
    inout  wire [27:0] gp, gn,
    output wire oled_csn,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire oled_resn,
    output wire wifi_gpio0
);
    assign wifi_gpio0 = btn[0];
    parameter C_color_bits = 8; // 8 or 16

    wire clk = clk_25mhz;

    wire [6:0] x;
    wire [5:0] y;

    //                  checkered     pixels  black
    wire  [7:0] color = x[3] ^ y[0] ? x     : 8'h00;

generate
if(0)  // driver type 0-oled 1-lcd (both should work)
begin
    wire oled_clkn; 
    lcd_video
    #(
        .c_init_file("ssd1306_linit_xflip.mem"),
        .c_init_size(59),
        .c_reset_us(1000),
        .c_clk_polarity(0),
        .c_x_size(128),
        .c_y_size(64),
        .c_color_bits(C_color_bits)
    )
    lcd_video_inst
    (
        .clk(clk),
        .reset(~btn[0]),
        .x(x),
        .y(y),
        .color(color),
        .spi_csn(oled_csn),
        .spi_clk(oled_clk),
        .spi_mosi(oled_mosi),
        .spi_dc(oled_dc),
        .spi_resn(oled_resn)
    );
end
else
begin
    oled_video
    #(
        .c_init_file("ssd1306_oinit_xflip.mem"),
        .c_init_size(31),
        .c_x_size(128),
        .c_y_size(64/8),
        .c_color_bits(C_color_bits)
    )
    oled_video_inst
    (
        .clk(clk),
        .reset(~btn[0]),
        .x(x),
        .y(y),
        .color(color),
        .spi_clk(gp[0]),
        .spi_mosi(gp[1]),
        .spi_csn(gp[2]),
        .spi_dc(gp[3])
    );
end
endgenerate
endmodule
