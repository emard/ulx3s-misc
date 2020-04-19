module top_hex_480x272
(
  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,
  output [27:0] gp, gn,
  output wifi_gpio0
);
    // wifi_gpio0=1 keeps board from rebooting
    // hold btn0 to let ESP32 take control over the board
    assign wifi_gpio0 = btn[0];

    // clock generator
    wire clk_175MHz, clk_25MHz, clk_locked;
    clk_25_175_25
    clock_instance
    (
      .clk25_i(clk_25mhz),
      .clk175_o(clk_175MHz),
      .clk25_o(clk_25MHz),
      .locked(clk_locked)
    );
    
    // shift clock choice SDR/DDR
    wire clk_pixel = clk_25MHz;
    wire clk_shift = clk_175MHz;

    parameter C_bits = 256;
    reg [C_bits-1:0] R_display; // something to display
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
      R_display[31+128:128] <= R_display[31+128:128] + 1; // shown in next OLED row
    end

    parameter C_color_bits = 16; 
    wire [9:0] x;
    wire [9:0] y;
    // for reverse screen:
    wire [9:0] rx = 480-4-x;
    wire [C_color_bits-1:0] color;
    hex_decoder_v
    #(
        .c_data_len(C_bits),
        .c_row_bits(5), // 2**n digits per row (4*2**n bits/row) 3->32, 4->64, 5->128, 6->256 
        .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
        .c_font_file("hex_font.mem"),
        .c_x_bits(9),
        .c_y_bits(4),
	.c_color_bits(C_color_bits)
    )
    hex_decoder_v_inst
    (
        .clk(clk_pixel),
        .data(R_display),
        .x(rx[9:1]),
        .y(y[4:1]),
        .color(color)
    );

    // VGA signal generator
    wire [7:0] vga_r, vga_g, vga_b;
    assign vga_r = {color[15:11],color[11],color[11],color[11]};
    assign vga_g = {color[10:5],color[5],color[5]};
    assign vga_b = {color[4:0],color[0],color[0],color[0]};
    wire vga_hsync, vga_vsync, vga_blank;
    vga
    #(
      // https://github.com/Xilinx/embeddedsw/blob/master/XilinxProcessorIPLib/drivers/video_common/src/xvidc_timings_table.c
      .C_resolution_x(480),
      .C_hsync_front_porch(24),
      .C_hsync_pulse(48),
      .C_hsync_back_porch(72),
      .C_resolution_y(272),
      .C_vsync_front_porch(1),
      .C_vsync_pulse(3),
      .C_vsync_back_porch(19),
      .C_bits_x(10),
      .C_bits_y(10)
    )
    vga_instance
    (
      .clk_pixel(clk_pixel),
      .clk_pixel_ena(1'b1),
      .test_picture(1'b0), // enable test picture generation
      .beam_x(x),
      .beam_y(y),
      //.vga_r(vga_r),
      //.vga_g(vga_g),
      //.vga_b(vga_b),
      .vga_hsync(vga_hsync),
      .vga_vsync(vga_vsync),
      .vga_blank(vga_blank)
    );
    
    assign led[7:3] = btn[4:0];
    assign led[0] = vga_vsync;
    assign led[1] = vga_hsync;
    assign led[2] = vga_blank;

    // VGA to digital video converter
    wire [3:0] lvds;
    vga2lvds
    vga2lvds_instance
    (
      .clk_pixel(clk_pixel),
      .clk_shift(clk_shift),
      .in_red(vga_r),
      .in_green(vga_g),
      .in_blue(vga_b),
      .in_hsync(vga_hsync),
      .in_vsync(vga_vsync),
      .in_blank(vga_blank),
      .out_lvds(lvds)
    );
    
    assign gp[6:3] = lvds;
    assign gn[6:3] = ~lvds;
    assign gn[8] = 1;

endmodule
