module top_checkered
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,
    output wire oled_csn,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire oled_resn,
    output wire wifi_gpio0
);
    assign wifi_gpio0 = btn[0];
    parameter C_color_bits = 16; // 8 or 16

/*
    wire clk, locked;
    pll
    pll_inst
    (
        .clki(clk_25mhz),
        .clko(clk), // 12.5 MHz
        .locked(locked)
    );
*/
    wire clk = clk_25mhz;

    wire [6:0] x;
    wire [5:0] y;

    generate
    if(C_color_bits < 12)
    begin
    //                  checkered      red   green   blue     red     green blue
    wire  [7:0] color = x[3] ^ y[3] ? {3'd0, x[6:4], 2'd0} : {y[5:3], 3'd0, 2'd0};
    localparam C_init_file = "oled_init.mem";
    //localparam C_init_file = "oled_init_xflip.mem";
    //localparam C_init_file = "oled_init_yflip.mem";
    //localparam C_init_file = "oled_init_xyflip.mem";
    end
    else
    begin
    //                  checkered      red   green   blue     red     green blue
    wire [15:0] color = x[3] ^ y[3] ? {5'd0, x[6:1], 5'd0} : {y[5:1], 6'd0, 5'd0};
    //localparam C_init_file = "oled_init_16bit.mem";
    localparam C_init_file = "ssd1351_init_xflip_16bit.mem";
    //localparam C_init_file = "oled_init_yflip_16bit.mem";
    //localparam C_init_file = "oled_init_xyflip_16bit.mem";
    end
    endgenerate

generate
if(1)  // driver type 0-oled 1-lcd (both should work)
begin
    wire oled_clkn; 
    lcd_video
    #(
        .c_init_file("ssd1351_linit_16bit.mem"),
        .c_init_size(59),
        .c_reset_us(1000),
        .c_clk_polarity(0),
        .c_x_size(128),
        .c_y_size(128),
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
        .c_init_file("ssd1351_init_xflip_16bit.mem"),
        .c_x_size(128),
        .c_y_size(128),
        .c_color_bits(C_color_bits)
    )
    oled_video_inst
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
endgenerate
/*
    oled_video
    #(
        .c_init_file(C_init_file),
        .c_x_size(128),
        .c_y_size(128),
        .c_color_bits(C_color_bits)
    )
    oled_video_inst
    (
        .clk(clk),
        .x(x),
        .y(y),
        .color(color),
        .spi_csn(oled_csn),
        .spi_clk(oled_clk),
        .spi_mosi(oled_mosi),
        .spi_dc(oled_dc),
        .spi_resn(oled_resn)
    );
*/
endmodule
