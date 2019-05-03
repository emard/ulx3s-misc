module ulx3s_ps2mouse_oled
(
  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,
  inout usb_fpga_dp, usb_fpga_dn,
  output usb_fpga_pu_dp, usb_fpga_pu_dn,
  output wire oled_csn,
  output wire oled_clk,
  output wire oled_mosi,
  output wire oled_dc,
  output wire oled_resn,
  output wifi_gpio0
);
    // wifi_gpio0=1 keeps board from rebooting
    // hold btn0 to let ESP32 take control over the board
    assign wifi_gpio0 = btn[0];
    wire clk;
    assign clk = clk_25mhz;
    // enable pullups
    assign usb_fpga_pu_dp = 1'b1;
    assign usb_fpga_pu_dn = 1'b1;

    wire ps2mdat_in, ps2mclk_in, ps2mdat_out, ps2mclk_out;
    
    assign usb_fpga_dp = ps2mclk_out ? 1'bz : 1'b0;
    assign usb_fpga_dn = ps2mdat_out ? 1'bz : 1'b0;
    assign ps2mclk_in = usb_fpga_dp;
    assign ps2mdat_in = usb_fpga_dn;

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

    wire [7:0] xcount, ycount;
    ps2mouse
    ps2mouse_inst
    (
      .clk(clk),
      .reset(reset),
      .ps2mdati(ps2mdat_in),
      .ps2mclki(ps2mclk_in),
      .ps2mdato(ps2mdat_out),
      .ps2mclko(ps2mclk_out),
      .xcount(xcount),
      .ycount(ycount),
      .btn(led[3:1])
    );
    assign led[7:6] = xcount[1:0];
    assign led[5:4] = ycount[1:0];

    wire [6:0] x;
    wire [5:0] y;
    // wire [15:0] color = x[3] ^ y[3] ? {5'd0, x[6:1], 5'd0} : {y[5:1], 6'd0, 5'd0};
    wire [15:0] color = x[6:0] == xcount[6:0] || y[5:0] == ycount[5:0] ? 16'hFFFF : 16'h0000;
    oled_video
    #(
        .C_init_file("oled_init_16bit.mem"),
        .C_color_bits(16)
    )
    oled_video_inst
    (
        .clk(clk),
        .x(x),
        .y(y),
        .color(color),
        .oled_csn(oled_csn),
        .oled_clk(oled_clk),
        .oled_mosi(oled_mosi),
        .oled_dc(oled_dc),
        .oled_resn(oled_resn)
    );
endmodule
