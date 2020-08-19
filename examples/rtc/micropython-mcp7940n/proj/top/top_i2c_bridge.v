`default_nettype none
module top_i2c_bridge
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,
    inout  wire [27:0] gp,gn,
    inout  wire shutdown,
    inout  wire gpdi_sda,
    inout  wire gpdi_scl,
    input  wire ftdi_txd,
    output wire ftdi_rxd,
    inout  wire sd_clk, sd_cmd,
    inout  wire [3:0] sd_d,
    output wire wifi_en,
    input  wire wifi_txd,
    output wire wifi_rxd,
    inout  wire wifi_gpio17,
    inout  wire wifi_gpio16,
    output wire wifi_gpio5,
    output wire wifi_gpio0
);
    assign wifi_gpio0 = btn[0];
    assign wifi_en    = 1;
/*
  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(  6*1000000), .out0_tol_hz(1000000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks)
  );
    wire clk = clocks[0];
*/
    wire clk = clk_25mhz;

    assign sd_clk     = 1'bz; // wifi_gpio14
    assign sd_cmd     = 1'bz; // wifi_gpio15
    //assign sd_d[0]    = 1'bz; // wifi_gpio2
    assign sd_d[1]    = 1'bz; // wifi_gpio4
    assign sd_d[2]    = 1'bz; // wifi_gpio12
    assign sd_d[3]    = 1;    // SD card inactive at SPI bus
    
    reg eink_dc, eink_sdi, eink_cs, eink_clk, eink_busy;
    always @(posedge clk)
    begin
      eink_dc   <= gp[11];  // wifi_gpio26
      eink_sdi  <= gn[11];  // wifi_gpio25
      eink_cs   <= sd_cmd;  // wifi_gpio15
      eink_clk  <= sd_clk;  // wifi_gpio14
      eink_busy <= gp[4];   // wifi_gpio5
    end
    assign gp[0]      = eink_dc;
    assign gp[1]      = eink_sdi;
    assign gp[2]      = eink_cs;
    assign gp[3]      = eink_clk;
    assign wifi_gpio5 = eink_busy;

    // passthru to ESP32 micropython serial console
    assign wifi_rxd = ftdi_txd;
    assign ftdi_rxd = wifi_txd;

    // i2c bridge
    // slow clock enable pulse 2.77 MHz
    localparam bridge_clk_div = 3; // div = 1+2^n, 25/9=2.77 MHz
    reg [bridge_clk_div:0] bridge_cnt;
    always @(posedge clk) // 25 MHz
    begin
      if(bridge_cnt[bridge_clk_div])
        bridge_cnt <= 0;
      else
        bridge_cnt <= bridge_cnt + 1;
    end
    wire clk_bridge_en = bridge_cnt[bridge_clk_div];

    wire [1:0] i2c_sda_i = {gpdi_sda, wifi_gpio16};
    wire [1:0] i2c_sda_t;
    i2c_bridge i2c_sda_bridge_i
    (
      .clk(clk),
      .clk_en(clk_bridge_en),
      .i(i2c_sda_i),
      .t(i2c_sda_t)
    );
    assign gpdi_sda    = i2c_sda_t[1] ? 1'bz : 1'b0;
    assign wifi_gpio16 = i2c_sda_t[0] ? 1'bz : 1'b0;

    wire [1:0] i2c_scl_i = {gpdi_scl, wifi_gpio17};
    wire [1:0] i2c_scl_t;
    i2c_bridge i2c_scl_bridge_i
    (
      .clk(clk),
      .clk_en(clk_bridge_en),
      .i(i2c_scl_i),
      .t(i2c_scl_t)
    );
    assign gpdi_scl    = i2c_scl_t[1] ? 1'bz : 1'b0;
    assign wifi_gpio17 = i2c_scl_t[0] ? 1'bz : 1'b0;

    assign led[4:0] = {eink_busy,eink_clk,eink_cs,eink_sdi,eink_dc};
    assign led[5]   = shutdown;
    assign led[7:6] = {gpdi_sda,gpdi_scl};

    // shutdown fuze
    // while cs=1 toggle dc 9 times
    localparam fuze_div = 3;
    reg [fuze_div:0] fuze_cnt = 0;
    reg r_eink_dc = 0;
    always @(posedge clk)
    begin
      if(fuze_cnt[fuze_div]==0)
      begin
        if(eink_cs)
        begin
          if(r_eink_dc & ~eink_dc) // falling edge
            fuze_cnt <= fuze_cnt + 1;
        end
        else
          fuze_cnt <= 0;
      end
      r_eink_dc <= eink_dc;
    end
    assign shutdown = fuze_cnt[fuze_div] ? 1'b1 : 1'bz;

endmodule
