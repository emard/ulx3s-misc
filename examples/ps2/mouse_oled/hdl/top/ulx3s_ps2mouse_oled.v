module ulx3s_ps2mouse_oled
#(
  parameter mousecore = 1 // 0-minimig 1-oberon
)
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

    wire [2:0] mouse_btn;
    wire [9:0] mouse_x, mouse_y, mouse_z;

    generate
      if(mousecore == 0) // using amiga core
      begin
        wire ps2mdat_in, ps2mclk_in, ps2mdat_out, ps2mclk_out;
        assign usb_fpga_dp = ps2mclk_out ? 1'bz : 1'b0;
        assign usb_fpga_dn = ps2mdat_out ? 1'bz : 1'b0;
        assign ps2mclk_in = usb_fpga_dp;
        assign ps2mdat_in = usb_fpga_dn;
        ps2mouse
        #(
          .c_x_bits(10),
          .c_y_bits(10)
        )
        ps2mouse_amiga_inst
        (
          .clk(clk),
          .reset(reset),
          .ps2mdati(ps2mdat_in),
          .ps2mclki(ps2mclk_in),
          .ps2mdato(ps2mdat_out),
          .ps2mclko(ps2mclk_out),
          .xcount(mouse_x),
          .ycount(mouse_y),
          .btn(mouse_btn)
        );
      end
      if(mousecore == 1) // using oberon core
      begin
        mousem
        #(
          .c_x_bits(10),
          .c_y_bits(10),
          .c_z_bits(10)
        )
        ps2mouse_oberon_inst
        (
          .clk(clk),
          .reset(reset),
          .msclk(usb_fpga_dp),
          .msdat(usb_fpga_dn),
          .x(mouse_x),
          .y(mouse_y),
          .z(mouse_z),
          .btn(mouse_btn)
        );
      end
    endgenerate

    assign led[7:6] = mouse_y[1:0];
    assign led[5:4] = mouse_x[1:0];
    assign led[3:1] = mouse_btn;

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
endmodule
