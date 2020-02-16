module top_hex_640x480
(
  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,
  output [3:0] gpdi_dp,
  output wifi_gpio0
);
    parameter C_ddr = 1'b1; // 0:SDR 1:DDR

    // wifi_gpio0=1 keeps board from rebooting
    // hold btn0 to let ESP32 take control over the board
    assign wifi_gpio0 = btn[0];

    // clock generator
    wire clk_250MHz, clk_125MHz, clk_25MHz, clk_locked;
    clk_25_250_125_25
    clock_instance
    (
      .clk25_i(clk_25mhz),
      .clk250_o(clk_250MHz),
      .clk125_o(clk_125MHz),
      .clk25_o(clk_25MHz),
      .locked(clk_locked)
    );
    
    // shift clock choice SDR/DDR
    wire clk_pixel, clk_shift;
    assign clk_pixel = clk_25MHz;
    generate
      if(C_ddr == 1'b1)
        assign clk_shift = clk_125MHz;
      else
        assign clk_shift = clk_250MHz;
    endgenerate

    // LED blinky
    localparam counter_width = 28;
    wire [7:0] countblink;
    blink
    #(
      .bits(counter_width)
    )
    blink_instance
    (
      .clk(clk_pixel),
      .led(countblink)
    );
    assign led[7:6] = countblink[7:6];

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

    parameter C_color_bits = 16; 
    wire [9:0] x;
    wire [9:0] y;
    // for reverse screen:
    wire [9:0] rx = 636-x;
    wire [C_color_bits-1:0] color;
    hex_decoder_v
    #(
        .c_data_len(256),
        .c_row_bits(5),
        .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
        .c_font_file("hex_font.mem"),
        .c_x_bits(8),
        .c_y_bits(8),
	.c_color_bits(C_color_bits)
    )
    hex_decoder_v_inst
    (
        .clk(clk_pixel),
        .data(R_display),
        .x(rx[9:2]),
        .y(y[9:2]),
        .color(color)
    );

    // VGA signal generator
    wire [7:0] vga_r, vga_g, vga_b;
    assign vga_r = {color[15:11],color[11],color[11],color[11]};
    assign vga_g = {color[10:5],color[5],color[5]};
    assign vga_b = {color[4:0],color[0],color[0],color[0]};
    wire vga_hsync, vga_vsync, vga_blank;
    vga
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
    
    assign led[0] = vga_vsync;
    assign led[1] = vga_hsync;
    assign led[2] = vga_blank;

    // VGA to digital video converter
    wire [1:0] tmds[3:0];
    vga2dvid
    #(
      .C_ddr(C_ddr),
      .C_shift_clock_synchronizer(1'b1)
    )
    vga2dvid_instance
    (
      .clk_pixel(clk_pixel),
      .clk_shift(clk_shift),
      .in_red(vga_r),
      .in_green(vga_g),
      .in_blue(vga_b),
      .in_hsync(vga_hsync),
      .in_vsync(vga_vsync),
      .in_blank(vga_blank),
      .out_clock(tmds[3]),
      .out_red(tmds[2]),
      .out_green(tmds[1]),
      .out_blue(tmds[0])
    );

    // output TMDS SDR/DDR data to fake differential lanes
    fake_differential
    #(
      .C_ddr(C_ddr)
    )
    fake_differential_instance
    (
      .clk_shift(clk_shift),
      .in_clock(tmds[3]),
      .in_red(tmds[2]),
      .in_green(tmds[1]),
      .in_blue(tmds[0]),
      .out_p(gpdi_dp)
      //.out_n(gpdi_dn)
    );

endmodule
