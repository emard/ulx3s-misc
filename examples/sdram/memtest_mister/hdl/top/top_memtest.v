module top_memtest
(
  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,
  output [3:0] gpdi_dp, gpdi_dn,
  output wifi_gpio0
);
    parameter C_ddr = 1'b1; // 0:SDR 1:DDR

    // wifi_gpio0=1 keeps board from rebooting
    // hold btn0 to let ESP32 take control over the board
    assign wifi_gpio0 = btn[0];

    // clock generator
    wire clk_shift, clk_pixel, clk_locked;
    clk_25_shift_pixel
    clock_instance
    (
      .clki(clk_25mhz),
      .clko(clk_shift),
      .clks1(clk_pixel),
      .locked(clk_locked)
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
    assign led[0] = btn[1];
    assign led[7:1] = countblink[7:1];


    reg [10:0] freq[11];
    initial
    begin
      freq[0]  = 12'h167;
      freq[1]  = 12'h160;
      freq[2]  = 12'h150;
      freq[3]  = 12'h140;
      freq[4]  = 12'h130;
      freq[5]  = 12'h120;
      freq[6]  = 12'h110;
      freq[7]  = 12'h100;
      freq[8]  = 12'h90;
      freq[9]  = 12'h80;
      freq[10] = 12'h70;
    end
    reg   [3:0] pos  = 0;
    reg  [15:0] mins = 0;
    reg  [15:0] secs = 0;
    reg         auto = 0;
    reg         ph_shift = 0;
    reg  [31:0] pre_phase;
    wire [31:0] passcount, failcount;

    // VGA signal generator
    wire VGA_DE;
    wire [1:0] vga_r, vga_g, vga_b;
    vgaout showrez
    (
        .clk(clk_pixel),
        .rez1(passcount),
        .rez2(failcount),
        .freq(16'hF000 | freq[pos]),
        .elapsed(ph_shift ? pre_phase[15:0] : mins),
        .mark(ph_shift ? 8'hF0 : auto ? 8'h80 >> secs[3:0] : 8'd0),
        .hs(vga_hsync),
        .vs(vga_vsync),
        .de(VGA_DE),
        .r(vga_r),
        .g(vga_g),
        .b(vga_b)
    );
    assign vga_blank = ~VGA_DE;

    // VGA to digital video converter
    wire [1:0] tmds[3:0];
    vga2dvid
    #(
      .C_depth(2),
      .C_ddr(C_ddr)
    )
    vga2dvid_instance
    (
      .clk_pixel(clk_pixel),
      .clk_shift(clk_shift),
      .in_red(vga_r),
      .in_green(vga_g),
      .in_blue(vga_b),
      .in_hsync(~vga_hsync),
      .in_vsync(~vga_vsync),
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
