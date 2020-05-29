module top_vgatest
#(
  //  modes tested on lenovo monitor
  //  640x400  @50Hz
  //  640x400  @60Hz
  //  640x480  @50Hz
  //  640x480  @60Hz
  //  720x576  @50Hz
  //  720x576  @60Hz
  //  800x480  @60Hz
  //  800x600  @60Hz
  // 1024x768  @60Hz
  // 1280x768  @60Hz
  // 1366x768  @60Hz
  // 1280x1024 @60Hz
  // 1920x1080 @30Hz
  // 1920x1080 @50Hz overclock 540MHz
  // 1920x1200 @50Hz overclock 600MHz
  parameter x =  640,      // pixels
  parameter y =  480,      // pixels
  parameter f =   60,      // Hz 60,50,30
  parameter xadjustf =  0, // adjust -3..3 if no picture
  parameter yadjustf =  0, // or to fine-tune f
  parameter C_ddr    =  1  // 0:SDR 1:DDR
)
(
  input        clk_25mhz,
  input  [6:0] btn,
  output [7:0] led,
  output [3:0] gpdi_dp,
  output       user_programn,
  output       wifi_gpio0
);

  function integer F_find_next_f(input integer f);
    integer f0;
    if(120000000>f)
      f0=120000000; // overclock
    if(108000000>f)
      f0=108000000; // overclock
    if(100000000>f)
      f0=100000000; // overclock
    if(80000000>f)
      f0=80000000;  // overclock
    if(75000000>f)
      f0=75000000;
    if(65000000>f)
      f0=65000000;
    if(60000000>f)
      f0=60000000;
    if(54000000>f)
      f0=54000000;
    if(50000000>f)
      f0=50000000;
    if(40000000>f)
      f0=40000000;
    if(27000000>f)
      f0=27000000;
    if(25000000>f)
      f0=25000000;
    F_find_next_f=f0;
  endfunction
  
  localparam xminblank         = x/64; // initial estimate
  localparam yminblank         = y/64; // for minimal blank space
  localparam min_pixel_f       = f*(x+xminblank)*(y+yminblank);
  localparam pixel_f           = F_find_next_f(min_pixel_f);
  localparam yframe            = y+yminblank;
  localparam xframe            = pixel_f/(f*yframe);
  localparam xblank            = xframe-x;
  localparam yblank            = yframe-y;
  localparam hsync_front_porch = xblank/3;
  localparam hsync_pulse_width = xblank/3;
  localparam hsync_back_porch  = xblank-hsync_pulse_width-hsync_front_porch+xadjustf;
  localparam vsync_front_porch = yblank/3;
  localparam vsync_pulse_width = yblank/3;
  localparam vsync_back_porch  = yblank-vsync_pulse_width-vsync_front_porch+yadjustf;

  
  // wifi_gpio0=1 keeps board from rebooting
  // hold btn0 to let ESP32 take control over the board
  assign wifi_gpio0 = btn[0];

  // press BTN0 to exit this bitstream
  reg [19:0] R_delay_reload = 0;
  always @(posedge clk_25mhz)
    if(R_delay_reload[19]==0)
      R_delay_reload <= R_delay_reload+1;
  assign user_programn = btn[0] | ~R_delay_reload[19];

  // clock generator
  wire clk_locked;
  wire [3:0] clocks;
  wire clk_shift = clocks[0];
  wire clk_pixel = clocks[1];
  ecp5pll
  #(
      .in_hz(25000000),
    .out0_hz(pixel_f*5*(C_ddr?1:2)),
    .out1_hz(pixel_f)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(clk_locked)
  );
  // VGA signal generator
  wire [7:0] vga_r, vga_g, vga_b;
  wire vga_hsync, vga_vsync, vga_blank;
  vga
  #(
    .C_resolution_x(x),
    .C_hsync_front_porch(hsync_front_porch),
    .C_hsync_pulse(hsync_pulse_width),
    .C_hsync_back_porch(hsync_back_porch),
    .C_resolution_y(y),
    .C_vsync_front_porch(vsync_front_porch),
    .C_vsync_pulse(vsync_pulse_width),
    .C_vsync_back_porch(vsync_back_porch),
    .C_bits_x(12),
    .C_bits_y(11)
  )
  vga_instance
  (
    .clk_pixel(clk_pixel),
    .clk_pixel_ena(1'b1),
    .test_picture(1'b1), // enable test picture generation
    .vga_r(vga_r),
    .vga_g(vga_g),
    .vga_b(vga_b),
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .vga_blank(vga_blank)
  );

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
  
  assign led[0] = vga_vsync;
  assign led[1] = vga_hsync;
  assign led[2] = vga_blank;

  // VGA to digital video converter
  wire [1:0] tmds[3:0];
  vga2dvid
  #(
    .C_ddr(C_ddr?1'b1:1'b0),
    .C_shift_clock_synchronizer(1'b0)
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

  generate
    if(C_ddr)
    begin
      // vendor specific DDR modules
      // convert SDR 2-bit input to DDR clocked 1-bit output (single-ended)
      // onboard GPDI
      ODDRX1F ddr0_clock (.D0(tmds[3][0]), .D1(tmds[3][1]), .Q(gpdi_dp[3]), .SCLK(clk_shift), .RST(0));
      ODDRX1F ddr0_red   (.D0(tmds[2][0]), .D1(tmds[2][1]), .Q(gpdi_dp[2]), .SCLK(clk_shift), .RST(0));
      ODDRX1F ddr0_green (.D0(tmds[1][0]), .D1(tmds[1][1]), .Q(gpdi_dp[1]), .SCLK(clk_shift), .RST(0));
      ODDRX1F ddr0_blue  (.D0(tmds[0][0]), .D1(tmds[0][1]), .Q(gpdi_dp[0]), .SCLK(clk_shift), .RST(0));
    end
    else
    begin
      assign gpdi_dp[3] = tmds[3][0];
      assign gpdi_dp[2] = tmds[2][0];
      assign gpdi_dp[1] = tmds[1][0];
      assign gpdi_dp[0] = tmds[0][0];
    end
  endgenerate

/*
  // external GPDI
  ODDRX1F ddr1_clock (.D0(tmds[3][0]), .D1(tmds[3][1]), .Q(gp[12]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr1_red   (.D0(tmds[2][0]), .D1(tmds[2][1]), .Q(gp[11]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr1_green (.D0(tmds[1][0]), .D1(tmds[1][1]), .Q(gp[10]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr1_blue  (.D0(tmds[0][0]), .D1(tmds[0][1]), .Q(gp[ 9]), .SCLK(clk_shift), .RST(0));
*/

endmodule
