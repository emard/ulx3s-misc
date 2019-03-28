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

    wire clk, locked;
    pll
    pll_inst
    (
        .clki(clk_25mhz),
        .clko(clk), // 12.5 MHz
        .locked(locked)
    );

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
    wire next_pixel;
    wire [C_color_bits-1:0] color;

    hex_decoder
    #(
        .C_data_len(128),
        .C_font_file("oled_font.mem"),
        .C_color_bits(C_color_bits)
    )
    hex_decoder_inst
    (
        .clk(clk),
        .en(1'b1),
        .data(R_display),
        .x(x),
        .y(y),
        .next_pixel(next_pixel),
        .color(color)
    );
    
    generate
      if(C_color_bits < 12)
        localparam C_init_file = "oled_init_xflip.mem";
      else
        localparam C_init_file = "oled_init_xflip_16bit.mem";
    endgenerate

    oled_video
    #(
        .C_init_file(C_init_file),
        .C_color_bits(C_color_bits)
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
