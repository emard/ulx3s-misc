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

    /*
    wire ps2mdat_in, ps2mclk_in, ps2mdat_out, ps2mclk_out;
    
    assign usb_fpga_dp = ps2mclk_out ? 1'bz : 1'b0;
    assign usb_fpga_dn = ps2mdat_out ? 1'bz : 1'b0;
    assign ps2mclk_in = usb_fpga_dp;
    assign ps2mdat_in = usb_fpga_dn;
    */

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

    wire [8:0] x_increment, y_increment;
    ps2_mouse_interface
    #(
       .WATCHDOG_TIMER_VALUE_PP(10000),
       .DEBOUNCE_TIMER_VALUE_PP(100)
    )
    ps2_mouse_interface_inst
    (
      .clk(clk),
      .reset(reset),
      .ps2_clk(usb_fpga_dp),
      .ps2_data(usb_fpga_dn),
      .x_increment(x_increment),
      .y_increment(y_increment),
      .left_button(led[2]),
      .right_button(led[1]),
      .read(1'b1)
    );
    assign led[7:6] = y_increment[1:0];
    assign led[5:4] = x_increment[1:0];
endmodule
