// AUTHOR=Paul Ruiz
// LICENSE=BSD

module kbd_top
(
  input   clk_25mhz,
  output  [7:0] led,
  output wire usb_fpga_pu_dp, usb_fpga_pu_dn,
  input  wire usb_fpga_dp, usb_fpga_dn,
  output wire wifi_gpio0
);

  wire clk_25mhz;

  assign wifi_gpio0     = 1'b1;
  
  // enable pull ups on both D+ and D-
  assign usb_fpga_pu_dp = 1'b1; 
  assign usb_fpga_pu_dn = 1'b1;

  wire ps2clk  = usb_fpga_dp;
  wire ps2data = usb_fpga_dn;
  
  PS2KBD kbd(clk_25mhz, ps2clk, ps2data, led, , );

endmodule
