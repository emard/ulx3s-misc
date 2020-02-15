module top_hex_demo
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,
    output wire oled_csn,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire oled_resn
);
    parameter C_color_bits = 16; 

    assign led = 0;

    reg [127:0] R_display; // something to display
    always @(posedge clk_25mhz)
    begin
      R_display[0] <= btn[0];
      R_display[4] <= btn[1];
      R_display[8] <= btn[2];
      R_display[12] <= btn[3];
      R_display[16] <= btn[4];
      R_display[20] <= btn[5];
      R_display[24] <= btn[6];
      R_display[58:52] <= btn;
      R_display[127:64] <= R_display[127:64] + 1; // shown in next OLED row
    end

    wire [7:0] x;
    wire [7:0] y;
    // for reverse screen:
    wire [7:0] ry = 239-y;
    wire [C_color_bits-1:0] color;
    hex_decoder_v
    #(
        .C_data_len(128),
        .C_row_bits(4),
        .C_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
        .C_font_file("hex_font.mem"),
	.C_color_bits(C_color_bits)
    )
    hex_decoder_v_inst
    (
        .clk(clk_25mhz),
        .data(R_display),
        .x(x[7:1]),
        .y(ry[7:1]),
        .color(color)
    );

    // allow large combinatorial logic
    // to calculate color(x,y)
    wire next_pixel;
    reg [C_color_bits-1:0] R_color;
    always @(posedge clk_25mhz)
      if(next_pixel)
        R_color <= color;

    lcd_video
    #(
        .c_clk_mhz(25),
        .c_init_file("st7789_init.mem"),
        .c_init_size(36)
    )
    lcd_video_inst
    (
        .clk(clk_25mhz),
        .reset(~btn[0]),
        .x(x),
        .y(y),
        .next_pixel(next_pixel),
        .color(R_color),
        .oled_csn(oled_csn),
        .oled_clk(oled_clk),
        .oled_mosi(oled_mosi),
        .oled_dc(oled_dc),
        .oled_resn(oled_resn)
    );

endmodule
