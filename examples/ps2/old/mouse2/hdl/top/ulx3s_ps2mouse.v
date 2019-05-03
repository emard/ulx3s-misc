module ulx3s_ps2mouse
(
  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,
  inout usb_fpga_dp, usb_fpga_dn,
  output usb_fpga_pu_dp, usb_fpga_pu_dn,
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

    wire [11:0] mx, my;
    ps2_mouse_xy
    ps2_mouse_xy_inst
    (
      .clk(clk),
      .reset(reset),
      .ps2_clk(usb_fpga_dp),
      .ps2_data(usb_fpga_dn),
      .mx(mx),
      .my(my),
      .btn_click(led[3:1])
    );
    assign led[7:6] = my[1:0];
    assign led[5:4] = mx[1:0];
    
endmodule
