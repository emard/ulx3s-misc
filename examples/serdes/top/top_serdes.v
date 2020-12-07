`default_nettype none
module top_serdes
(
  input         clk_25mhz,
  output        oled_clk,  oled_mosi, // refclkn_d0,   refclkp_d0
  output        oled_resn, oled_dc,   // hdrxn0_d0ch1, hdrxp0_d0ch1
  output        oled_csn,  oled_bl,   // hdrxn0_d0ch0, hdrxp0_d0ch0
  input   [6:0] btn,
  output  [7:0] led
);
  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz( 25000000),
    .out0_hz( 30000000),                 .out0_tol_hz(0),
    .out1_hz( 60000000), .out1_deg(  0), .out1_tol_hz(0),
    .out2_hz(100000000), .out2_deg(  0), .out2_tol_hz(0),
    .out3_hz(25000000),  .out3_deg(  0), .out3_tol_hz(0)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks)
  );
  wire clk = clocks[2]; // 100 MHz
  wire rst = btn[1];

  // some demo clock to serdes RX
  wire refclk_d0   = clocks[3]; // 250 MHz
  wire hdrx0_d0ch0 = clocks[3]; // 250 MHz
  wire hdrx0_d0ch1 = clocks[3]; // 250 MHz

  // fake differential to serdes (shared with oled)
  assign oled_clk  = ~refclk_d0;
  assign oled_mosi =  refclk_d0;
  assign oled_resn = ~hdrx0_d0ch1;
  assign oled_dc   =  hdrx0_d0ch1;
  assign oled_csn  = ~hdrx0_d0ch0;
  assign oled_bl   =  hdrx0_d0ch0;

  wire tx_pclk, rx_pclk; // serdes block generates those clocks

  reg [30:0] ctr;
  reg comma;
  wire [3:0] disp;
    
  always @(posedge tx_pclk) begin
    ctr <= ctr + 1'b1;
    comma <= &(ctr[7:0]);    
  end
    
  wire [7:0] txd = ctr[30:23];
  wire [7:0] rxd;
  //assign led = rxd;
  assign led = {rxd[7:4]|rxd[3:0],disp};
    
  wire tx_pcs_rst = rst, rx_pcs_rst = rst, rx_ser_rst = rst, tx_ser_rst = rst, dual_rst = rst, serdes_dual_rst = rst;
  wire tx_pwrup = 1'b1, rx_pwrup = 1'b1, serdes_pdb = 1'b1;
  wire rx_los_lol, rx_cdr_lol;

  // see fpga-toolchain/share/yosys/ecp5/cells_bb.v
  // DCUA EXTREFB PCSCLKDIV

  (* LOC="DCU0" *)
  DCUA DCU0_inst
  (
    .CH0_HDINP(), .CH1_HDINP(),
    .CH0_FFC_FB_LOOPBACK(1'b1), .CH1_FFC_FB_LOOPBACK(1'b1),
    .CH1_RX_REFCLK(clk),
    .CH1_FF_RXI_CLK(rx_pclk), .CH1_FF_RX_PCLK(rx_pclk),
    .CH1_FF_TXI_CLK(tx_pclk), .CH1_FF_TX_PCLK(tx_pclk),
    .CH1_FF_TX_D_0(txd[0]), .CH1_FF_TX_D_1(txd[1]),  .CH1_FF_TX_D_2(txd[2]),  .CH1_FF_TX_D_3(txd[3]),
    .CH1_FF_TX_D_4(txd[4]), .CH1_FF_TX_D_5(txd[5]),  .CH1_FF_TX_D_6(txd[6]),  .CH1_FF_TX_D_7(txd[7]),
    .CH1_FF_TX_D_8(comma),  .CH1_FF_TX_D_9(1'b0)  ,  .CH1_FF_TX_D_10(1'b0),   .CH0_FF_TX_D_11(1'b0),
    .CH1_FFC_EI_EN(1'b0), .CH1_FFC_SIGNAL_DETECT(1'b0), .CH1_FFC_LANE_TX_RST(tx_pcs_rst), .CH1_FFC_LANE_RX_RST(rx_pcs_rst),
    .CH1_FFC_RRST(rx_ser_rst), .CH1_FFC_TXPWDNB(tx_pwrup), .CH1_FFC_RXPWDNB(rx_pwrup), .D_FFC_DUAL_RST(dual_rst),
    .D_FFC_MACRO_RST(serdes_dual_rst), .D_FFC_MACROPDB(serdes_pdb), .D_FFC_TRST(tx_ser_rst),
    .CH1_FF_RX_D_0(rxd[0]), .CH1_FF_RX_D_1(rxd[1]), .CH1_FF_RX_D_2(rxd[2]), .CH1_FF_RX_D_3(rxd[3]),
    .CH1_FF_RX_D_4(rxd[4]), .CH1_FF_RX_D_5(rxd[5]), .CH1_FF_RX_D_6(rxd[6]), .CH1_FF_RX_D_7(rxd[7]),
    .CH1_FFS_RLOS(rx_los_lol), .CH1_FFS_RLOL(rx_cdr_lol),
    .D_REFCLKI(clk)
  );
    defparam DCU0_inst.D_MACROPDB = "0b1";
    defparam DCU0_inst.D_IB_PWDNB = "0b1";
    defparam DCU0_inst.D_XGE_MODE = "0b0";
    defparam DCU0_inst.D_LOW_MARK = "0d4";
    defparam DCU0_inst.D_HIGH_MARK = "0d12";
    defparam DCU0_inst.D_BUS8BIT_SEL = "0b0";
    defparam DCU0_inst.D_CDR_LOL_SET = "0b00";
    defparam DCU0_inst.D_TXPLL_PWDNB = "0b1";
    defparam DCU0_inst.D_BITCLK_LOCAL_EN = "0b1";
    defparam DCU0_inst.D_BITCLK_ND_EN = "0b0";
    defparam DCU0_inst.D_BITCLK_FROM_ND_EN = "0b0";
    defparam DCU0_inst.D_SYNC_LOCAL_EN = "0b1";
    defparam DCU0_inst.D_SYNC_ND_EN = "0b0";
    defparam DCU0_inst.CH1_UC_MODE = "0b1";
    defparam DCU0_inst.CH1_PCIE_MODE = "0b0";
    defparam DCU0_inst.CH1_RIO_MODE = "0b0";
    defparam DCU0_inst.CH1_WA_MODE = "0b1";
    defparam DCU0_inst.CH1_INVERT_RX = "0b0";
    defparam DCU0_inst.CH1_INVERT_TX = "0b0";
    defparam DCU0_inst.CH1_PRBS_SELECTION = "0b0";
    defparam DCU0_inst.CH1_GE_AN_ENABLE = "0b0";
    defparam DCU0_inst.CH1_PRBS_LOCK = "0b0";
    defparam DCU0_inst.CH1_PRBS_ENABLE = "0b0";
    defparam DCU0_inst.CH1_ENABLE_CG_ALIGN = "0b1";
    defparam DCU0_inst.CH1_TX_GEAR_MODE = "0b0";
    defparam DCU0_inst.CH1_RX_GEAR_MODE = "0b0";
    defparam DCU0_inst.CH1_PCS_DET_TIME_SEL = "0b00";
    defparam DCU0_inst.CH1_PCIE_EI_EN = "0b0";
    defparam DCU0_inst.CH1_TX_GEAR_BYPASS = "0b0";
    defparam DCU0_inst.CH1_ENC_BYPASS = "0b1";
    defparam DCU0_inst.CH1_SB_BYPASS = "0b0";
    defparam DCU0_inst.CH1_RX_SB_BYPASS = "0b0";
    defparam DCU0_inst.CH1_WA_BYPASS = "0b0";
    defparam DCU0_inst.CH1_DEC_BYPASS = "0b1";
    defparam DCU0_inst.CH1_CTC_BYPASS = "0b1";
    defparam DCU0_inst.CH1_RX_GEAR_BYPASS = "0b0";
    defparam DCU0_inst.CH1_LSM_DISABLE = "0b0";
    defparam DCU0_inst.CH1_MIN_IPG_CNT = "0b11";
    defparam DCU0_inst.CH1_UDF_COMMA_MASK = "0x3ff";
    defparam DCU0_inst.CH1_UDF_COMMA_A = "0x283";
    defparam DCU0_inst.CH1_UDF_COMMA_B = "0x17C";
    defparam DCU0_inst.CH1_RX_DCO_CK_DIV = "0b000";
    defparam DCU0_inst.CH1_RCV_DCC_EN = "0b0";
    defparam DCU0_inst.CH1_TPWDNB = "0b1";
    defparam DCU0_inst.CH1_RATE_MODE_TX = "0b0";
    defparam DCU0_inst.CH1_RTERM_TX = "0d19";
    defparam DCU0_inst.CH1_TX_CM_SEL = "0b00";
    defparam DCU0_inst.CH1_TDRV_PRE_EN = "0b0";
    defparam DCU0_inst.CH1_TDRV_SLICE0_SEL = "0b01";
    defparam DCU0_inst.CH1_TDRV_SLICE1_SEL = "0b00";
    defparam DCU0_inst.CH1_TDRV_SLICE2_SEL = "0b01";
    defparam DCU0_inst.CH1_TDRV_SLICE3_SEL = "0b01";
    defparam DCU0_inst.CH1_TDRV_SLICE4_SEL = "0b00";
    defparam DCU0_inst.CH1_TDRV_SLICE5_SEL = "0b00";
    defparam DCU0_inst.CH1_TDRV_SLICE0_CUR = "0b011";
    defparam DCU0_inst.CH1_TDRV_SLICE1_CUR = "0b000";
    defparam DCU0_inst.CH1_TDRV_SLICE2_CUR = "0b11";
    defparam DCU0_inst.CH1_TDRV_SLICE3_CUR = "0b10";
    defparam DCU0_inst.CH1_TDRV_SLICE4_CUR = "0b00";
    defparam DCU0_inst.CH1_TDRV_SLICE5_CUR = "0b00";
    defparam DCU0_inst.CH1_TDRV_DAT_SEL = "0b00";
    defparam DCU0_inst.CH1_TX_DIV11_SEL = "0b0";
    defparam DCU0_inst.CH1_RPWDNB = "0b1";
    defparam DCU0_inst.CH1_RATE_MODE_RX = "0b0";
    defparam DCU0_inst.CH1_RX_DIV11_SEL = "0b0";
    defparam DCU0_inst.CH1_SEL_SD_RX_CLK = "0b1";
    defparam DCU0_inst.CH1_FF_RX_H_CLK_EN = "0b0";
    defparam DCU0_inst.CH1_FF_RX_F_CLK_DIS = "0b0";
    defparam DCU0_inst.CH1_FF_TX_H_CLK_EN = "0b0";
    defparam DCU0_inst.CH1_FF_TX_F_CLK_DIS = "0b0";
    defparam DCU0_inst.CH1_TDRV_POST_EN = "0b0";
    defparam DCU0_inst.CH1_TX_POST_SIGN = "0b0";
    defparam DCU0_inst.CH1_TX_PRE_SIGN = "0b0";
    defparam DCU0_inst.CH1_REQ_LVL_SET = "0b00";
    defparam DCU0_inst.CH1_REQ_EN = "0b1";
    defparam DCU0_inst.CH1_RTERM_RX = "0d22";
    defparam DCU0_inst.CH1_RXTERM_CM = "0b11";
    defparam DCU0_inst.CH1_PDEN_SEL = "0b1";
    defparam DCU0_inst.CH1_RXIN_CM = "0b11";
    defparam DCU0_inst.CH1_LEQ_OFFSET_SEL = "0b0";
    defparam DCU0_inst.CH1_LEQ_OFFSET_TRIM = "0b000";
    defparam DCU0_inst.CH1_RLOS_SEL = "0b1";
    defparam DCU0_inst.CH1_RX_LOS_LVL = "0b100";
    defparam DCU0_inst.CH1_RX_LOS_CEQ = "0b11";
    defparam DCU0_inst.CH1_RX_LOS_HYST_EN = "0b0";
    defparam DCU0_inst.CH1_RX_LOS_EN = "0b1";
    defparam DCU0_inst.CH1_LDR_RX2CORE_SEL = "0b0";
    defparam DCU0_inst.CH1_LDR_CORE2TX_SEL = "0b0";
    //defparam DCU0_inst.D_TX_MAX_RATE = "2.5";
    //defparam DCU0_inst.CH1_CDR_MAX_RATE = "2.5";
    //defparam DCU0_inst.CH1_TXAMPLITUDE = "0d600";
    //defparam DCU0_inst.CH1_TXDEPRE = "DISABLED";
    //defparam DCU0_inst.CH1_TXDEPOST = "DISABLED";
    //defparam DCU0_inst.CH1_PROTOCOL = "G8B10B";
    defparam DCU0_inst.D_ISETLOS = "0d0";
    defparam DCU0_inst.D_SETIRPOLY_AUX = "0b10";
    defparam DCU0_inst.D_SETICONST_AUX = "0b01";
    defparam DCU0_inst.D_SETIRPOLY_CH = "0b10";
    defparam DCU0_inst.D_SETICONST_CH = "0b10";
    defparam DCU0_inst.D_REQ_ISET = "0b001";
    defparam DCU0_inst.D_PD_ISET = "0b00";
    defparam DCU0_inst.D_DCO_CALIB_TIME_SEL = "0b00";
    defparam DCU0_inst.CH1_CDR_CNT4SEL = "0b00";
    defparam DCU0_inst.CH1_CDR_CNT8SEL = "0b00";
    defparam DCU0_inst.CH1_DCOATDCFG = "0b00";
    defparam DCU0_inst.CH1_DCOATDDLY = "0b00";
    defparam DCU0_inst.CH1_DCOBYPSATD = "0b1";
    defparam DCU0_inst.CH1_DCOCALDIV = "0b000";
    defparam DCU0_inst.CH1_DCOCTLGI = "0b011";
    defparam DCU0_inst.CH1_DCODISBDAVOID = "0b0";
    defparam DCU0_inst.CH1_DCOFLTDAC = "0b00";
    defparam DCU0_inst.CH1_DCOFTNRG = "0b001";
    defparam DCU0_inst.CH1_DCOIOSTUNE = "0b010";
    defparam DCU0_inst.CH1_DCOITUNE = "0b00";
    defparam DCU0_inst.CH1_DCOITUNE4LSB = "0b010";
    defparam DCU0_inst.CH1_DCOIUPDNX2 = "0b1";
    defparam DCU0_inst.CH1_DCONUOFLSB = "0b100";
    defparam DCU0_inst.CH1_DCOSCALEI = "0b01";
    defparam DCU0_inst.CH1_DCOSTARTVAL = "0b010";
    defparam DCU0_inst.CH1_DCOSTEP = "0b11";
    defparam DCU0_inst.CH1_BAND_THRESHOLD = "0d0";
    defparam DCU0_inst.CH1_AUTO_FACQ_EN = "0b1";
    defparam DCU0_inst.CH1_AUTO_CALIB_EN = "0b1";
    defparam DCU0_inst.CH1_CALIB_CK_MODE = "0b0";
    defparam DCU0_inst.CH1_REG_BAND_OFFSET = "0d0";
    defparam DCU0_inst.CH1_REG_BAND_SEL = "0d0";
    defparam DCU0_inst.CH1_REG_IDAC_SEL = "0d0";
    defparam DCU0_inst.CH1_REG_IDAC_EN = "0b0";
    defparam DCU0_inst.D_CMUSETISCL4VCO = "0b000";
    defparam DCU0_inst.D_CMUSETI4VCO = "0b00";
    defparam DCU0_inst.D_CMUSETINITVCT = "0b00";
    defparam DCU0_inst.D_CMUSETZGM = "0b000";
    defparam DCU0_inst.D_CMUSETP2AGM = "0b000";
    defparam DCU0_inst.D_CMUSETP1GM = "0b000";
    defparam DCU0_inst.D_CMUSETI4CPZ = "0d3";
    defparam DCU0_inst.D_CMUSETI4CPP = "0d3";
    defparam DCU0_inst.D_CMUSETICP4Z = "0b101";
    defparam DCU0_inst.D_CMUSETICP4P = "0b01";
    defparam DCU0_inst.D_CMUSETBIASI = "0b00";
    defparam DCU0_inst.D_SETPLLRC = "0d1";
    defparam DCU0_inst.CH1_RX_RATE_SEL = "0d10";
    defparam DCU0_inst.D_REFCK_MODE = "0b100";
    defparam DCU0_inst.D_TX_VCO_CK_DIV = "0b000";
    defparam DCU0_inst.D_PLL_LOL_SET = "0b00";
    defparam DCU0_inst.D_RG_EN = "0b0";
    defparam DCU0_inst.D_RG_SET = "0b00";

  reg [27:0] rx_hb, tx_hb;
  
  always @(posedge tx_pclk) tx_hb <= tx_hb + 1'b1;
  always @(posedge rx_pclk) rx_hb <= rx_hb + 1'b1;
  
  assign disp = {rx_los_lol, rx_cdr_lol, tx_hb[27], rx_hb[27]};

endmodule
