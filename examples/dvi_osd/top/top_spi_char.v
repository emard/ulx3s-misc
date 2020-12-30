`default_nettype none
module top_spi_char
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
  parameter x =   640,     // pixels
  parameter y =   480,     // pixels
  parameter f =    60,     // Hz 60,50,30
  parameter xadjustf =  0, // adjust -3..3 if no picture
  parameter yadjustf =  0, // or to fine-tune f
  parameter c_ddr    =  1  // 0:SDR 1:DDR
)
(
  input         clk_25mhz,
  input   [6:0] btn,
  output  [7:0] led,
  output  [3:0] gpdi_dp,
  input         ftdi_txd,
  output        ftdi_rxd,
  inout  [27:0] gp, gn,
  //inout         sd_clk, sd_cmd,
  //inout   [3:0] sd_d,
  input         wifi_txd,
  output        wifi_rxd,
  inout         wifi_gpio16,
  input         wifi_gpio5,
  output        wifi_gpio0
);

  function integer F_find_next_f(input integer f);
    if(25000000>f)
      F_find_next_f=25000000;
    else if(27000000>f)
      F_find_next_f=27000000;
    else if(40000000>f)
      F_find_next_f=40000000;
    else if(50000000>f)
      F_find_next_f=50000000;
    else if(54000000>f)
      F_find_next_f=54000000;
    else if(60000000>f)
      F_find_next_f=60000000;
    else if(65000000>f)
      F_find_next_f=65000000;
    else if(75000000>f)
      F_find_next_f=75000000;
    else if(80000000>f)
      F_find_next_f=80000000;  // overclock
    else if(100000000>f)
      F_find_next_f=100000000; // overclock
    else if(108000000>f)
      F_find_next_f=108000000; // overclock
    else if(120000000>f)
      F_find_next_f=120000000; // overclock
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

  // passthru to ESP32 micropython serial console
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;

  // SPI lines
  wire spi_csn, spi_sck, spi_mosi, spi_miso, spi_irq;
  // ESP32 -> FPGA
  assign spi_csn = ~wifi_gpio5;
  assign spi_sck = gn[11]; // wifi_gpio25
  assign spi_mosi = gp[11]; // wifi_gpio26
  // FPGA -> ESP32
  assign wifi_gpio16 = spi_miso;
  assign wifi_gpio0 = ~spi_irq; // wifi_gpio0 IRQ active low

  assign led = {spi_csn, spi_sck, spi_miso, spi_mosi, spi_irq};

  // clock generator
  wire clk_locked;
  wire [3:0] clocks;
  wire clk_shift = clocks[0];
  wire clk_pixel = clocks[1];
  wire clk_cpu   = clocks[1]; // can belong to differet clock domain than video
  ecp5pll
  #(
      .in_hz(25*1000000),
    .out0_hz(pixel_f*5*(c_ddr?1:2)),
    .out1_hz(pixel_f)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(clk_locked)
  );

  // offload BTNs
  reg [6:0] R_btn_joy;
  always @(posedge clk_cpu)
    R_btn_joy <= btn;

  // SPI slave to example BRAM storage
  wire        spi_ram_wr, spi_ram_rd;
  wire [31:0] spi_ram_addr;
  wire  [7:0] spi_ram_wr_data, spi_ram_rd_data;

  wire spi_irq;
  spi_ram_btn_v
  #(
    .c_sclk_capable_pin(1'b0),
    .c_addr_bits(32)
  )
  spi_ram_btn_inst
  (
    .clk(clk_cpu),
    .csn(spi_csn),
    .sclk(spi_sck),
    .mosi(spi_mosi),
    .miso(spi_miso),
    .btn(R_btn_joy),
    .irq(spi_irq),
    .wr(spi_ram_wr),
    .rd(spi_ram_rd),
    .addr(spi_ram_addr),
    .data_in(spi_ram_rd_data),
    .data_out(spi_ram_wr_data)
  );

  wire spi_ram_wr_cs = spi_ram_addr[31:24] == 8'h00 ? spi_ram_wr : 0;
  // example BRAM storage for testing
  // osd.poke(0,"12345678")
  // osd.peek(0,8)
  bram_true2p_2clk
  #(
    .dual_port(0),
    .data_width(8),
    .addr_width(4)  // 4 will allocate 2**4=16 bytes
  )
  bram
  (
    .clk_a(clk_cpu),
    .clken_a(1),
    .addr_a(spi_ram_addr),
    .we_a(spi_ram_wr_cs),
    .data_in_a(spi_ram_wr_data),
    .data_out_a(spi_ram_rd_data)
  );

  /*
  reg [7:0] ram_mem[0:15];
  reg [7:0] ram_out;
  always @(posedge clk_cpu)
  begin
    if(spi_ram_wr_cs)
      ram_mem[spi_ram_addr] <= spi_ram_wr_data;
    else
      ram_out <= ram_mem[spi_ram_addr];
  end
  assign spi_ram_rd_data = ram_out;
  */


  // VGA signal generator
  wire [7:0] vga_r, vga_g, vga_b;
  wire vga_hsync, vga_vsync, vga_blank;
  vga
  #(
    .c_resolution_x(x),
    .c_hsync_front_porch(hsync_front_porch),
    .c_hsync_pulse(hsync_pulse_width),
    .c_hsync_back_porch(hsync_back_porch),
    .c_resolution_y(y),
    .c_vsync_front_porch(vsync_front_porch),
    .c_vsync_pulse(vsync_pulse_width),
    .c_vsync_back_porch(vsync_back_porch),
    .c_bits_x(11),
    .c_bits_y(11)
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

  //assign led[0] = vga_vsync;
  //assign led[1] = vga_hsync;
  //assign led[2] = vga_blank;

  // OSD overlay
  wire [7:0] osd_vga_r, osd_vga_g, osd_vga_b;
  wire osd_vga_hsync, osd_vga_vsync, osd_vga_blank;
  spi_osd_v
  #(
    .c_sclk_capable_pin(1'b0),
    .c_bits_x(11),
    .c_bits_y(11),
    .c_transparency(1)
  )
  spi_osd_v_instance
  (
    .clk_pixel(clk_pixel),
    .clk_pixel_ena(1'b1),
    .i_r(vga_r),
    .i_g(vga_g),
    .i_b(vga_b),
    .i_hsync(vga_hsync),
    .i_vsync(vga_vsync),
    .i_blank(vga_blank),
    .i_csn(spi_csn),
    .i_sclk(spi_sck),
    .i_mosi(spi_mosi),
    .o_r(osd_vga_r),
    .o_g(osd_vga_g),
    .o_b(osd_vga_b),
    .o_hsync(osd_vga_hsync),
    .o_vsync(osd_vga_vsync),
    .o_blank(osd_vga_blank)
  );

  // VGA to digital video converter
  wire [1:0] tmds[3:0];
  vga2dvid
  #(
    .c_ddr(c_ddr),
    .c_shift_clock_synchronizer(1'b1)
  )
  vga2dvid_instance
  (
    .clk_pixel(clk_pixel),
    .clk_shift(clk_shift),
    .in_red(osd_vga_r),
    .in_green(osd_vga_g),
    .in_blue(osd_vga_b),
    .in_hsync(osd_vga_hsync),
    .in_vsync(osd_vga_vsync),
    .in_blank(osd_vga_blank),
    .out_clock(tmds[3]),
    .out_red(tmds[2]),
    .out_green(tmds[1]),
    .out_blue(tmds[0])
  );

  generate
    if(c_ddr)
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

endmodule
