module top_hex_demo
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
    wire [6:0] color;

    hex_decoder_v
    #(
        .c_data_len(128),
        .c_font_file("hex_font_h.mem"),
        .c_grid_6x8(1),
        .c_color_bits(7)
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
wire spi_clk,spi_mosi,spi_csn,spi_dc;
generate
if(1)  // driver type 0-oled 1-lcd (both should work)
begin
    lcd_video
    #(
        .c_init_file("ssd1306_linit_xflip.mem"),
        .c_init_size(64),
        .c_reset_us(1000),
        .c_clk_phase(0),
        .c_clk_polarity(1),
        .c_x_size(128),
        .c_y_size(64/8), // HACK for OLED1306 128x64
        .c_color_bits(8)
    )
    lcd_video_inst
    (
        .reset(~btn[0]),
        .clk_pixel(clk),
        .clk_spi(clk),
        .x(x),
        .y(y),
        .color(color),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_csn(spi_csn),
        .spi_dc(spi_dc)
    );
end
else
begin
    oled_video
    #(
        .c_init_file("ssd1306_oinit_xflip.mem"),
        .c_init_size(31),
        .c_x_size(128),
        .c_y_size(64/8), // HACK for OLED1306 128x64
        .c_color_bits(8)
    )
    oled_video_inst
    (
        .clk(clk),
        .reset(~btn[0]),
        .x(x),
        .y(y),
        .color({color,1'b0}), // expand 7 to 8 bits
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_csn(spi_csn),
        .spi_dc(spi_dc)
    );
end
endgenerate

assign oled_clk  = spi_clk;
assign oled_mosi = spi_mosi;
assign oled_csn  = spi_csn;
assign oled_dc   = spi_dc;
assign oled_res  = btn[1];

assign gp[0] = spi_clk;
assign gp[1] = spi_mosi;
assign gp[2] = spi_csn;
assign gp[3] = spi_dc;


endmodule
