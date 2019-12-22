module ulx3s_ps2mouse_oled_dvi
(
  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,
  inout usb_fpga_bd_dp, usb_fpga_bd_dn,
  output usb_fpga_pu_dp, usb_fpga_pu_dn,
  output wire oled_csn,
  output wire oled_clk,
  output wire oled_mosi,
  output wire oled_dc,
  output wire oled_resn,
  output [3:0] gpdi_dp, gpdi_dn,
  output wifi_gpio0
);
    parameter C_ddr = 1'b1; // 0:SDR 1:DDR

    wire [2:0] clocks;
    wire clk_locked;
    clk_25_250_125_25
    clock_instance
    (
      .clkin(clk_25mhz),
      .clkout0(clocks[0]),
      .clkout1(clocks[1]),
      .clkout2(clocks[2]),
      .locked(clk_locked)
    );
    wire clk_250MHz, clk_125MHz, clk_25MHz, clk_locked;
    assign clk_250MHz = clocks[0];
    assign clk_125MHz = clocks[1];
    assign clk_25MHz = clocks[2];

    // shift clock choice SDR/DDR
    wire clk_pixel, clk_shift;
    assign clk_pixel = clk_25MHz;
    generate
      if(C_ddr == 1'b1)
        assign clk_shift = clk_125MHz;
      else
        assign clk_shift = clk_250MHz;
    endgenerate

    // wifi_gpio0=1 keeps board from rebooting
    // hold btn0 to let ESP32 take control over the board
    assign wifi_gpio0 = btn[0];
    wire clk;
    assign clk = clk_25MHz;

    reg [19:0] reset_counter;
    always @(posedge clk)
    begin
      if(btn[0] == 1'b0 && reset_counter[19] == 1'b0)
        reset_counter <= reset_counter + 1;
      if(btn[0] == 1'b1)
        reset_counter <= 0;
    end
    wire reset;
    assign reset = reset_counter[19];
    assign led[0] = reset;

    wire ps2mdat_in, ps2mclk_in, ps2mdat_out, ps2mclk_out;
    
    assign usb_fpga_bd_dp = ps2mclk_out ? 1'bz : 1'b0;
    assign usb_fpga_bd_dn = ps2mdat_out ? 1'bz : 1'b0;
    assign ps2mclk_in = usb_fpga_bd_dp;
    assign ps2mdat_in = usb_fpga_bd_dn;

    // enable pullups
    assign usb_fpga_pu_dp = 1'b1;
    assign usb_fpga_pu_dn = 1'b1;

    wire [9:0] mouse_x, mouse_y;
    ps2mouse
    #(
      .c_x_bits(10),
      .c_y_bits(10)
    )
    ps2mouse_inst
    (
      .clk(clk_pixel),
      .reset(reset),
      .ps2mdati(ps2mdat_in),
      .ps2mclki(ps2mclk_in),
      .ps2mdato(ps2mdat_out),
      .ps2mclko(ps2mclk_out),
      .xcount(mouse_x),
      .ycount(mouse_y),
      .btn(led[3:1])
    );
    assign led[7:6] = mouse_y[1:0];
    assign led[5:4] = mouse_x[1:0];

    wire [6:0] oled_x;
    wire [5:0] oled_y;
    // wire [15:0] color = x[3] ^ y[3] ? {5'd0, x[6:1], 5'd0} : {y[5:1], 6'd0, 5'd0};
    wire [15:0] oled_color = oled_x[6:0] == mouse_x[6:0] || oled_y[5:0] == mouse_y[5:0] ? 16'hFFFF : 16'h0000;
    oled_video
    #(
        .C_init_file("oled_init_16bit.mem"),
        .C_color_bits(16)
    )
    oled_video_inst
    (
        .clk(clk),
        .x(oled_x),
        .y(oled_y),
        .color(oled_color),
        .oled_csn(oled_csn),
        .oled_clk(oled_clk),
        .oled_mosi(oled_mosi),
        .oled_dc(oled_dc),
        .oled_resn(oled_resn)
    );


    wire [9:0] dvi_x, dvi_y;
    reg [7:0] dvi_color;
    always @(posedge clk_pixel)
      dvi_color <= dvi_x[9:0] == mouse_x[9:0] || dvi_y[9:0] == mouse_y[9:0] ? 8'hFF : 8'h00;

    // VGA signal generator
    wire [7:0] vga_r, vga_g, vga_b;
    wire vga_hsync, vga_vsync, vga_blank;
    vga
    vga_instance
    (
      .clk_pixel(clk_pixel),
      .clk_pixel_ena(1'b1),
      .beam_x(dvi_x),
      .beam_y(dvi_y),
      .vga_hsync(vga_hsync),
      .vga_vsync(vga_vsync),
      .vga_blank(vga_blank)
    );

    // VGA to digital video converter
    wire [1:0] tmds[3:0];
    vga2dvid
    #(
      .C_ddr(C_ddr)
    )
    vga2dvid_instance
    (
      .clk_pixel(clk_pixel),
      .clk_shift(clk_shift),
      .in_red(dvi_color),
      .in_green(dvi_color),
      .in_blue(dvi_color),
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
      .out_p(gpdi_dp),
      .out_n(gpdi_dn)
    );

endmodule
