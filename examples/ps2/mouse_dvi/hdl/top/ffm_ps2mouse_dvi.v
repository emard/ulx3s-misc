module ffm_ps2mouse_dvi
#(
  parameter mousecore = 1 // 0-minimig 1-oberon
)
(
  input  clk_100mhz_p,
  inout  [7:0] fioa,
  //-- keyboard
  //alias ps2a_clk : std_logic is fioa(6);
  //alias ps2a_data : std_logic is fioa(4);
  //-- mouse
  //alias ps2b_clk : std_logic is fioa(3);
  //alias ps2b_data : std_logic is fioa(1);
  //-- module LED
  //alias led_green: std_logic is fioa(5); -- green LED
  //alias led_red: std_logic is fioa(7); -- red LED
  output [3:1] led,
  output [3:0] vid_d_p // core should use only positive when in differential mode
);
    parameter C_ddr = 1'b1; // 0:SDR 1:DDR

    wire [2:0] clocks;
    wire clk_locked;
    clk_100_250_125_25
    clock_instance
    (
      .clkin(clk_100mhz_p),
      .clkout0(clocks[0]),
      .clkout1(clocks[1]),
      .clkout2(clocks[2]),
      .locked(clk_locked)
    );
    wire clk_250MHz, clk_125MHz, clk_25MHz;
    assign clk_250MHz = clocks[0];
    assign clk_125MHz = clocks[1];
    assign clk_25MHz  = clocks[2];

    // shift clock choice SDR/DDR
    wire clk_pixel, clk_shift;
    assign clk_pixel = clk_25MHz;
    generate
      if(C_ddr == 1'b1)
        assign clk_shift = clk_125MHz;
      else
        assign clk_shift = clk_250MHz;
    endgenerate

    wire clk;
    assign clk = clk_25MHz;

    wire reset;
    assign reset = ~clk_locked;

    wire [2:0] mouse_btn;
    wire [9:0] mouse_x, mouse_y, mouse_z;

    generate
      if(mousecore == 0) // using amiga core
      begin
        wire ps2mdat_in, ps2mclk_in, ps2mdat_out, ps2mclk_out;
        assign fioa[3] = ps2mclk_out ? 1'bz : 1'b0;
        assign fioa[1] = ps2mdat_out ? 1'bz : 1'b0;
        assign ps2mclk_in = fioa[3];
        assign ps2mdat_in = fioa[1];
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
          .c_z_bits(10),
          .c_hotplug(1)
        )
        ps2mouse_oberon_inst
        (
          .clk(clk),
          .clk_ena(1'b1),
          .ps2m_reset(reset),
          .ps2m_clk(fioa[3]),
          .ps2m_dat(fioa[1]),
          .x(mouse_x),
          .y(mouse_y),
          .z(mouse_z),
          .btn(mouse_btn)
        );
      end
    endgenerate

    // PS/2 traffic shown on module LED
    assign fioa[5] = ~fioa[3];
    assign fioa[7] = ~fioa[1];
    assign led[3:1] = mouse_btn;
    
    wire [9:0] x, y;
    reg [7:0] color;
    always @(posedge clk_pixel)
      color <= x[9:0] == mouse_x[9:0] || y[9:0] == mouse_y[9:0] ? 8'hFF : 8'h00;

    // VGA signal generator
    wire vga_hsync, vga_vsync, vga_blank;
    vga
    vga_instance
    (
      .clk_pixel(clk_pixel),
      .clk_pixel_ena(1'b1),
      .beam_x(x),
      .beam_y(y),
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
      .in_red(color),
      .in_green(color),
      .in_blue(color),
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
      .out_p(vid_d_p),
      .out_n()
    );

endmodule
