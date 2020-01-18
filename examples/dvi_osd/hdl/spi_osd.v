// SPI receiver for OSD text window
// VGA video stream pipeline processor

module spi_osd
#(
  parameter C_start_x   = 64,  // x1  pixel
  parameter C_start_y   = 48,  // x1  pixel
  parameter C_chars_x   = 64,  // x8  pixel
  parameter C_chars_y   = 24,  // x16 pixel
  parameter C_char_file = "osd.mem",
  parameter C_font_file = "font_vga.mem"
)
(
  input  wire clk_pixel, clk_pixel_ena,
  input  wire [7:0] i_r,
  input  wire [7:0] i_g,
  input  wire [7:0] i_b,
  input  wire i_hsync, i_vsync, i_blank,
  input  wire i_csn, i_sclk, i_mosi,
  inout  wire o_miso,
  output wire [7:0] o_r,
  output wire [7:0] o_g,
  output wire [7:0] o_b,
  output wire o_hsync, o_vsync, o_blank
);

    reg [7:0] tile_map [0:C_chars_x*C_chars_y-1]; // tile memory (character map)
    initial
      $readmemh(C_char_file, tile_map);

    wire ram_wr;
    wire [15:0] ram_addr;
    wire [7:0] ram_di;
    reg  [7:0] ram_do;
    spirw_slave
    #(
        .C_sclk_capable_pin(1'b0)
    )
    spirw_slave_inst
    (
        .clk(clk_pixel),
        .csn(i_csn),
        .sclk(i_sclk),
        .mosi(i_mosi),
        .miso(o_miso),
        .wr(ram_wr),
        .addr(ram_addr),
        .data_in(ram_do),
        .data_out(ram_di)
    );
    always @(posedge clk_pixel)
    begin
      if(ram_wr)
        tile_map[ram_addr] <= ram_di;
      //ram_do <= tile_map[ram_addr];
    end

    wire [9:0] osd_x, osd_y;
    reg [7:0] font[0:4095];
    initial
      $readmemh(C_font_file, font);
    reg [7:0] data_out;
    always @(posedge clk_pixel)
      data_out[7:0] <= font[{ tile_map[(osd_y >> 4) * C_chars_x + (osd_x >> 3)], osd_y[3:0] }];
    wire [7:0] data_out_align = {data_out[0], data_out[7:1]};
    wire osd_pixel = data_out_align[7-osd_x[2:0]];

    wire [7:0] osd_r = osd_pixel ? 8'hff : 8'h50;
    wire [7:0] osd_g = osd_pixel ? 8'hff : 8'h30;
    wire [7:0] osd_b = osd_pixel ? 8'hff : 8'h20;

    // OSD overlay
    osd
    #(
      .C_x_start(C_start_x),
      .C_x_stop (C_start_x+8*C_chars_x-1),
      .C_y_start(C_start_y),
      .C_y_stop (C_start_y+16*C_chars_y-1)
    )
    osd_instance
    (
      .clk_pixel(clk_pixel),
      .clk_pixel_ena(1'b1),
      .i_r(i_r),
      .i_g(i_g),
      .i_b(i_b),
      .i_hsync(i_hsync),
      .i_vsync(i_vsync),
      .i_blank(i_blank),
      .o_osd_x(osd_x),
      .o_osd_y(osd_y),
      .i_osd_r(osd_r),
      .i_osd_g(osd_g),
      .i_osd_b(osd_b),
      .o_r(o_r),
      .o_g(o_g),
      .o_b(o_b),
      .o_hsync(o_hsync),
      .o_vsync(o_vsync),
      .o_blank(o_blank)
    );

endmodule
