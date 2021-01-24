module top_hex_demo
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
    parameter C_color_bits = 16; // 8 or 16
    assign wifi_gpio0 = btn[0];

    wire clk = clk_25mhz;

    reg [127:0] R_display; // something to display
    always @(posedge clk)
    begin
      R_display[0] <= btn[0];
      R_display[4] <= btn[1];
      R_display[8] <= btn[2];
      R_display[12] <= btn[3];
      R_display[16] <= btn[4];
      R_display[20] <= btn[5];
      R_display[24] <= btn[6];
      R_display[127:64] <= R_display[127:64] + 1; // shown in next OLED row
    end

    wire [6:0] x;
    wire [5:0] y;
    wire [C_color_bits-1:0] color;

    hex_decoder_v
    #(
        .c_data_len(128),
        .c_font_file("hex_font.mem"),
        .c_grid_6x8(1),
        .c_color_bits(C_color_bits)
    )
    hex_decoder_v_inst
    (
        .clk(clk),
        .data(R_display),
        .x(x),
        .y(y),
        .color(color)
    );

// we can use either lcd or oled video driver
// oled driver core and init is shorter
generate
if(1)  // driver type 0-oled 1-lcd (both should work)
begin
    wire oled_clkn; 
    lcd_video
    #(
        .c_init_file("ssd1351_linit_xflip_16bit.mem"),
        .c_init_size(59),
        .c_reset_us(1000),
        .c_clk_phase(0),
        .c_clk_polarity(1),
        .c_x_size(128),
        .c_y_size(128),
        .c_color_bits(C_color_bits)
    )
    lcd_video_inst
    (
        .reset(~btn[0]),
        .clk_pixel(clk),
        .clk_spi(clk),
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
        .c_init_file("ssd1351_oinit_xflip_16bit.mem"),
        .c_init_size(44),
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

endmodule
