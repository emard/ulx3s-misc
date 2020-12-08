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
      .in_hz( 25*1000000),
    .out0_hz( 25*1000000),                 .out0_tol_hz(0),
    .out1_hz( 50*1000000), .out1_deg(  0), .out1_tol_hz(0),
    .out2_hz(100*1000000), .out2_deg(  0), .out2_tol_hz(0),
    .out3_hz(250*1000000), .out3_deg(  0), .out3_tol_hz(0)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks)
  );
  wire clk = clocks[2]; // 100 MHz
  wire rst = btn[1];

  // some demo clock to serdes RX
  wire refclk_d0   = clocks[2]; // 100 MHz
  wire hdrx0_d0ch0 = clocks[3]; // 250 MHz
  wire hdrx0_d0ch1 = clocks[3]; // 250 MHz

  // fake differential to serdes (shared with oled)
  assign oled_clk  = ~refclk_d0;
  assign oled_mosi =  refclk_d0;
  assign oled_resn = ~hdrx0_d0ch1;
  assign oled_dc   =  hdrx0_d0ch1;
  assign oled_csn  = ~hdrx0_d0ch0;
  assign oled_bl   =  hdrx0_d0ch0;

  wire tx0_pclk, rx0_pclk; // serdes block generates those clocks
  wire tx1_pclk, rx1_pclk; // serdes block generates those clocks

  reg [30:0] ctr;
  reg comma;
  wire [3:0] disp0, disp1;
    
  always @(posedge tx1_pclk) begin
    ctr <= ctr + 1'b1;
    comma <= &(ctr[7:0]);    
  end
    
  wire [7:0] txd = ctr[30:23];
  wire [7:0] rxd0, rxd1;
  wire rx0_los_lol, rx0_cdr_lol;
  wire rx1_los_lol, rx1_cdr_lol;
  assign led = btn[2] ? {rxd1[7:4]|rxd1[3:0],disp1} : {rxd0[7:4]|rxd0[3:0],disp0};
    
  wire tx_pcs_rst = rst, rx_pcs_rst = rst, rx_ser_rst = rst, tx_ser_rst = rst, dual_rst = rst, serdes_dual_rst = rst;
  wire tx_pwrup = 1'b1, rx_pwrup = 1'b1, serdes_pdb = 1'b1;

  // see fpga-toolchain/share/yosys/ecp5/cells_bb.v
  // DCUA EXTREFB PCSCLKDIV

  (* LOC="DCU0" *)
  DCUA
  #(
    // ?: not found in TN1261
    .D_MACROPDB(1'b1), // 0: assert power down
    .D_IB_PWDNB(1'b1), // ?
    .D_XGE_MODE(1'b0), // 1: 10Gb XAUI LSM ethernet, 0: depends on channel mode selection
    .D_LOW_MARK(4'd4), // Clock compensation FIFO low water mark, mean is 4'd8
    .D_HIGH_MARK('d12), // Clock compensation FIFO high water mark, mean is 4'd8
    .D_BUS8BIT_SEL(1'b0), // 0: select 8-bit bus width, 1: select 10-bit bus width
    // D_CDR_LOL_SET: CDR loss of lock setting:
    //       lock              unlock
    // 00: +-1000 ppm x2     +-1500 ppm x2
    // 01: +-2000 ppm x2     +-2500 ppm x2
    // 10: +-4000 ppm        +-7000 ppm
    // 11: +- 300 ppm        +- 450 ppm
    .D_CDR_LOL_SET(2'b00),
    .D_TXPLL_PWDNB(1'b1), // TXPLL power down control: 0: power down, 1: power up
    .D_BITCLK_LOCAL_EN(1'b1), // ? enable local clock (ch0)
    .D_BITCLK_ND_EN(1'b0), // ? clock from neighboring dual (ch0->ch1)
    .D_BITCLK_FROM_ND_EN(1'b0), // ? pass clock from neighboring dual (ch0->ch1)
    .D_SYNC_LOCAL_EN(1'b1), // ?
    .D_SYNC_ND_EN(1'b0), // ?
    .D_TX_MAX_RATE(2.5), // TX max data rate 0.27-3.125/5.0
    .D_ISETLOS('d0), // ?
    .D_SETIRPOLY_AUX(2'b10), // ?
    .D_SETICONST_AUX(2'b01), // ?
    .D_SETIRPOLY_CH(2'b10), // ?
    .D_SETICONST_CH(2'b10), // ?
    .D_REQ_ISET(3'b001), // ?
    .D_PD_ISET(2'b00), // ?
    .D_DCO_CALIB_TIME_SEL(2'b00), // ?
    .D_CMUSETISCL4VCO(3'b000), // ?
    .D_CMUSETI4VCO(2'b00), // ?
    .D_CMUSETINITVCT(3'b00), // ?
    .D_CMUSETZGM(3'b000), // ?
    .D_CMUSETP2AGM(3'b000), // ?
    .D_CMUSETP1GM(3'b000), // ?
    .D_CMUSETI4CPZ('d3), // ?
    .D_CMUSETI4CPP('d3), // ?
    .D_CMUSETICP4Z(3'b101), // ?
    .D_CMUSETICP4P(2'b01), // ?
    .D_CMUSETBIASI(2'b00), // ?
    .D_SETPLLRC('d1), // ?
    // D_REFCK_MODE: MSB of REFCK_MODE is REFCK25X bit
    // 000: internal high speed bit clock is 20x
    // 001: internal high speed bit clock is 10x
    // 010: internal high speed bit clock is 16x
    // 011: internal high speed bit clock is  8x
    // 1xx: internal high speed bit clock is 25x
    .D_REFCK_MODE(3'b100),
    // D_TX_VCO_CK_DIV: VCO output frequency select, divide by:
    // 00x: x/1, 01x: x/2, 100: x/4, 101: x/8, 110: x/16, 111:x/32
    .D_TX_VCO_CK_DIV(3'b000),
    // D_PLL_LOL_SET: TxPLL loss of lock setting
    //       lock              unlock
    // 00: +- 300 ppm x2     +- 600 ppm x2
    // 01: +- 300 ppm        +-2000 ppm
    // 10: +-1500 ppm        +-2200 ppm
    // 11: +-4000 ppm        +-600 ppm
    .D_PLL_LOL_SET(2'b00),
    .D_RG_EN(1'b0), // ?
    .D_RG_SET(2'b00), // ?

    // common channel settings
    .CH0_UC_MODE(1'b1), // 1: selects user configured mode, 0: selects other mode PCIe, RapidIO, 10GbE, 1GBE
    .CH0_PCIE_MODE(1'b0), // 1: PCI express mode of operation, 0: Selects other mode (RapidIO, 10GbE, 1GBE)
    .CH0_RIO_MODE(1'b0), // 1: RapidIO mode, 0: Selects other mode (10GbE, 1GBE)
    .CH0_WA_MODE(1'b1), // 1: bitslip word alignment mode, 0: barrel shift word alignment mode
    .CH0_PRBS_SELECTION(1'b0), // ?
    .CH0_PRBS_LOCK(1'b0), // ?
    .CH0_PRBS_ENABLE(1'b0), // ?
    .CH0_GE_AN_ENABLE(1'b0), // GigE Auto Negotiation: 1: enable, 0: disable
    .CH0_PCIE_EI_EN(1'b0), // 1: PCI Express Electrical Idle, 0: Normal operation

    // RX settings
    .CH0_RPWDNB(1'b1), // receiver channel power: 0: power down, 1: power up
    .CH0_INVERT_RX(1'b0), // received data: 1: invert, 0: normal
    // CHx_ENABLE_CG_ALIGN: only valid when operating in uc_mode
    .CH0_RLOS_SEL(1'b1), // 0: Disabled, 1: Enabled (If the channel is being used, this bit should be set to 1)
    .CH0_ENABLE_CG_ALIGN(1'b1), // continuous comma alignment: 1: enable, 0: disable
    .CH0_UDF_COMMA_MASK(10'h3ff), // user defined comma mask
    .CH0_UDF_COMMA_A(10'h283), // user defined comma character 'a'
    .CH0_UDF_COMMA_B(10'h17C), // user defined comma character 'b'
    .CH0_RX_GEAR_MODE(1'b0), // 2:1 gearing for receive path on selected channels: 1: enable, 0: disable (no gearing)
    .CH0_PCS_DET_TIME_SEL(2'b00), // PCS connection detection time: 11: 16us, 10: 4us, 01: 2us, 00: 8us
    .CH0_RX_SB_BYPASS(1'b0), // invert RX data after SerDes bridge: 1: invert, 0: normal (note: loopback data is inverted)
    .CH0_WA_BYPASS(1'b0), // word alignment: 1: bypass, 0: normal operation
    .CH0_DEC_BYPASS(1'b1), // 8b10 decoder: 1: bypass, 0: normal operation
    .CH0_CTC_BYPASS(1'b1), // clock toleration compensation: 1: bypass, 0: normal operation
    .CH0_RX_GEAR_BYPASS(1'b0), // PCS Rx gear box: 1: bypass, 0: normal operation
    .CH0_LSM_DISABLE(1'b0), // Rx link state machine: 1: Disable, 0: Enable
    .CH0_MIN_IPG_CNT(1'b11), // minimum IPG to enforce
    .CH0_RX_DCO_CK_DIV(3'b000), // VCO output frequency divide by: 00x: x/1, 01x: x/2, 100: x/4, 101: x/8, 110: x/16, 111: x/32
    .CH0_RCV_DCC_EN(1'b0), // receiver coupling: 1: DC, 0: AC
    .CH0_RATE_MODE_RX(1'b0), // RX rate selection: 0: full rate, 1: half rate
    .CH0_RX_DIV11_SEL(1'b0), // RX rate selection SMPTE: 0: full rate, high definition SMPTE, 1: x/11 rate, standard definition SMPTE
    // CHx_SEL_SD_RX_CLK: FPGA bridge write clock and elastic buffer read clock driven by:
    .CH0_SEL_SD_RX_CLK(1'b1), // buffer driven by: 1: serdes recovered clock, 0: ff_ebrd_clk
    .CH0_FF_RX_H_CLK_EN(1'b0), // 1: enable, 0: disable
    .CH0_FF_RX_F_CLK_DIS(1'b0), // 1: disable, 0: enable
    .CH0_REQ_LVL_SET(2'b00), // level setting for equalization: 00: 6 dB, 01: 9 dB, 10: 12 dB, 11: not used
    .CH0_REQ_EN(1'b1), // receiver equalization: 1: enable, 0: disable
    .CH0_RTERM_RX(5'd19), // RX termination R ohm: 0: 5K, 1: 80, 4: 75, 6: 70, 11: 60, 19: 50, 25: 46, other: reserved
    .CH0_RXTERM_CM(2'b11), // Common mode voltage for RX input termination: 00: RX input supply, 01: Floating (AC Ground), 10: GND, 11: RX input supply
    // CHx_PDEN_SEL: this signal is used to disable the phase detector
    // in the CDR during electrical idle.
    // when set to 1 (enabled), checks if los is set.
    // If los is 0 then disables the phase detector (or data loop)
    .CH0_PDEN_SEL(1'b1), // 1: enable, 0: disable
    .CH0_RXIN_CM(2'b11), // Common mode for equalizer input in AC coupling: 00: 0.7V, 01: 0.65V, 10: 0.75V: 11: CMFB
    // CHx_LEQ_OFFSET: linear equalizer setting
    // this is used to selectively amplify high frequency components
    // more which are attenuated more on the backplane - similar to the
    // function performed by de-emphasis of the transmitter.
    // Four levels of equalization can be selected. ?
    .CH0_LEQ_OFFSET_SEL(1'b0), // ?
    .CH0_LEQ_OFFSET_TRIM(3'b000), // ?
    // CHx_RLOS_SEL: enables LOS detector output before enabling CDR
    // phase detector after calibration.
    .CH0_RX_LOS_LVL(3'b100), // Sets differential p-p threshold voltage for loss of signal detection
    .CH0_RX_LOS_CEQ(2'b11), // Sets the equalization value at input stage of LOS detector
    .CH0_RX_LOS_HYST_EN(1'b0), // Enables hysteresis in detection treshold level
    .CH0_RX_LOS_EN(1'b1), // Enables LOS of signal detector: 0: Disabled, 1: Enabled
    // enables boundary scan input path for routing the high speed RX
    // inputs to a lower speed Serdes in the FPGA (for out of band application)
    .CH0_LDR_RX2CORE_SEL(1'b0), // Low speed serial data RX: 1: Enabled, 0: Disabled (normal operation)

    // TX settings
    .CH0_TPWDNB(1'b1), // transmit channel power: 0: power down, 1: power up
    .CH0_INVERT_TX(1'b0), // transmitted data: 1: invert, 0: normal
    .CH0_SB_BYPASS(1'b0), // invert TX data after SerDes bridge; 1: invert, 0: normal (note: loopback data is inverted)
    .CH0_ENC_BYPASS(1'b1), // 1: bypass 8b10 encoder, 0: Normal operation
    .CH0_RATE_MODE_TX(1'b0), // rate selection for transmit: 1: full rate, 0: half rate
    // CHx_RTERM_TX: TX resistor termination select. Disabled when PCIe is enabled
    .CH0_RTERM_TX(5'd19), // TX termination R ohm: 0: 5K, 1: 80, 4: 75, 6: 70, 11: 60, 19: 50, 25: 46, other: reserved
    .CH0_TX_GEAR_BYPASS(1'b0), // PCS Tx gear box 1: bypass, 0: Normal operation
    .CH0_TX_GEAR_MODE(1'b0), // 2:1 gearing for trasmit path on selected channels: 1: enable, 0: disable (no gearing)
    .CH0_TX_CM_SEL(2'b00), // TX output common mode: 00: power down, 01: 0.6V, 10: 0.55V, 11: 0.5V
    .CH0_TDRV_PRE_EN(1'b0), // TX driver pre-emphasis: 1: enable, 0: disable
    .CH0_TDRV_POST_EN(1'b0), // TX driver post-emphasis: 1: enable, 0:disable
    .CH0_TX_PRE_SIGN(1'b0), // TX pre-emphasis sign: 1: not inverted, 0: inverted
    .CH0_TX_POST_SIGN(1'b0), // TX post-emphasis sign: 1: not inverted, 0: inverted
    .CH0_TDRV_SLICE0_SEL(2'b01), // TX drive slice enable for slice0: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    .CH0_TDRV_SLICE1_SEL(2'b00), // TX drive slice enable for slice1: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    .CH0_TDRV_SLICE2_SEL(2'b01), // TX drive slice enable for slice2: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    .CH0_TDRV_SLICE3_SEL(2'b01), // TX drive slice enable for slice3: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    .CH0_TDRV_SLICE4_SEL(2'b00), // TX drive slice enable for slice4: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    .CH0_TDRV_SLICE5_SEL(2'b00), // TX drive slice enable for slice5: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    // TX driver slice current settings:
    // increases the output current of slice by 100 uA
    // which corresponds to 100 mV in output amplitude
    .CH0_TDRV_SLICE0_CUR(3'd3), // slice 0 swing uA: 0: 100, 1: 200, 2: 300, 3: 400, 4: 500, 5: 600, 6:700, 7:800
    .CH0_TDRV_SLICE1_CUR(3'd0), // slice 1 swing uA: 0: 100, 1: 200, 2: 300, 3: 400, 4: 500, 5: 600, 6:700, 7:800
    .CH0_TDRV_SLICE2_CUR(2'd3), // slice 2 swing uA: 0: 800, 1: 1600, 2: 2400, 3: 3200
    .CH0_TDRV_SLICE3_CUR(2'd2), // slice 3 swing uA: 0: 800, 1: 1600, 2: 2400, 3: 3200
    .CH0_TDRV_SLICE4_CUR(2'd0), // slice 4 swing uA: 0: 800, 1: 1600, 2: 2400, 3: 3200
    .CH0_TDRV_SLICE5_CUR(2'd0), // slice 5 swing uA: 0: 800, 1: 1600, 2: 2400, 3: 3200
    // CHx_TDRV_DAT_SEL: Driver output select
    // 00: Data from Serializer muxed to driver (normal operation)
    // 01: Data rate clock from Serializer muxed to driver
    // 10: Serial Rx to Tx LB (data) if slb_r2t_dat_en=1
    // 10: Serial Rx to Tx LB (clock) if slb_r2t_ck_en=1
    // 11: Serial LB from equalizer to driver if slb_eq2t_en=1
    .CH0_TDRV_DAT_SEL(2'b00),
    .CH0_TX_DIV11_SEL(1'b0), // TX rate selection SMPTE: 0: full rate, high definition SMPTE, 1: x/11 rate, standard definition SMPTE
    .CH0_FF_TX_H_CLK_EN(1'b0), // 1: enable, 0: disable
    .CH0_FF_TX_F_CLK_DIS(1'b0), // 1: disable, 0: enable
    //.CH0_CDR_MAX_RATE(2.5), // Receive max data rate (CDR)
    //.CH0_TXAMPLITUDE('d600), // TX amplitude in mV, acceptable values 100-1300 (steps of 20)
    //.CH0_TXDEPRE(DISABLED), // De-emphasis pre-cursor select: DISABLED, 0-11
    //.CH0_TXDEPOST(DISABLED), // De-emphasis post-cursor select: DISABLED, 0-11
    .CH0_PROTOCOL("8BSER"), // "8B10B", "G8B10B", "PCIe", "GbE", "SGMII", "XAUI", "SDI", "CPRI", "JESD204", "10BSER", "8BSER", "eDP"
    .CH0_CDR_CNT4SEL(2'b00), // ?
    .CH0_CDR_CNT8SEL(2'b00), // ?
    .CH0_DCOATDCFG(2'b00), // ?
    .CH0_DCOATDDLY(2'b00), // ?
    .CH0_DCOBYPSATD(1'b1), // ?
    .CH0_DCOCALDIV(3'b000), // ?
    .CH0_DCOCTLGI(3'b011), // ?
    .CH0_DCODISBDAVOID(1'b0), // ?
    .CH0_DCOFLTDAC(2'b00), // ?
    .CH0_DCOFTNRG(3'b001), // ?
    .CH0_DCOIOSTUNE(3'b010), // ?
    .CH0_DCOITUNE(2'b00), // ?
    .CH0_DCOITUNE4LSB(3'b010), // ?
    .CH0_DCOIUPDNX2(1'b1), // ?
    .CH0_DCONUOFLSB(3'b100), // ?
    .CH0_DCOSCALEI(2'b01), // ?
    .CH0_DCOSTARTVAL(3'b010), // ?
    .CH0_DCOSTEP(2'b11), // ?
    .CH0_BAND_THRESHOLD('d0), // ?
    .CH0_AUTO_FACQ_EN(1'b1), // ? reset signal to trigger the DCO frequency acquisition process when it's necessary
    .CH0_AUTO_CALIB_EN(1'b1), // ? reset signal to trigger the DCO calibration process when it's necessary
    .CH0_CALIB_CK_MODE(1'b0), // ?
    .CH0_REG_BAND_OFFSET('d0), // ?
    .CH0_REG_BAND_SEL('d0), // ?
    .CH0_REG_IDAC_SEL('d0), // ?
    .CH0_REG_IDAC_EN(1'b0), // ?
    .CH0_RX_RATE_SEL(4'd10), // Equalizer pole position select
    // enables to transmit slow data from FPGA core to serdes TX
    .CH0_LDR_CORE2TX_SEL(1'b0), // Low speed serial data TX: 1: Enabled, 0: Disabled (normal operation)

    // common channel settings
    .CH1_UC_MODE(1'b1), // 1: selects user configured mode, 0: selects other mode PCIe, RapidIO, 10GbE, 1GBE
    .CH1_PCIE_MODE(1'b0), // 1: PCI express mode of operation, 0: Selects other mode (RapidIO, 10GbE, 1GBE)
    .CH1_RIO_MODE(1'b0), // 1: RapidIO mode, 0: Selects other mode (10GbE, 1GBE)
    .CH1_WA_MODE(1'b1), // 1: bitslip word alignment mode, 0: barrel shift word alignment mode
    .CH1_PRBS_SELECTION(1'b0), // ?
    .CH1_PRBS_LOCK(1'b0), // ?
    .CH1_PRBS_ENABLE(1'b0), // ?
    .CH1_GE_AN_ENABLE(1'b0), // GigE Auto Negotiation: 1: enable, 0: disable
    .CH1_PCIE_EI_EN(1'b0), // 1: PCI Express Electrical Idle, 0: Normal operation

    // RX settings
    .CH1_RPWDNB(1'b1), // receiver channel power: 0: power down, 1: power up
    .CH1_INVERT_RX(1'b0), // received data: 1: invert, 0: normal
    // CHx_ENABLE_CG_ALIGN: only valid when operating in uc_mode
    .CH1_RLOS_SEL(1'b1), // 0: Disabled, 1: Enabled (If the channel is being used, this bit should be set to 1)
    .CH1_ENABLE_CG_ALIGN(1'b1), // continuous comma alignment: 1: enable, 0: disable
    .CH1_UDF_COMMA_MASK(10'h3ff), // user defined comma mask
    .CH1_UDF_COMMA_A(10'h283), // user defined comma character 'a'
    .CH1_UDF_COMMA_B(10'h17C), // user defined comma character 'b'
    .CH1_RX_GEAR_MODE(1'b0), // 2:1 gearing for receive path on selected channels: 1: enable, 0: disable (no gearing)
    .CH1_PCS_DET_TIME_SEL(2'b00), // PCS connection detection time: 11: 16us, 10: 4us, 01: 2us, 00: 8us
    .CH1_RX_SB_BYPASS(1'b0), // invert RX data after SerDes bridge: 1: invert, 0: normal (note: loopback data is inverted)
    .CH1_WA_BYPASS(1'b0), // word alignment: 1: bypass, 0: normal operation
    .CH1_DEC_BYPASS(1'b1), // 8b10 decoder: 1: bypass, 0: normal operation
    .CH1_CTC_BYPASS(1'b1), // clock toleration compensation: 1: bypass, 0: normal operation
    .CH1_RX_GEAR_BYPASS(1'b0), // PCS Rx gear box: 1: bypass, 0: normal operation
    .CH1_LSM_DISABLE(1'b0), // Rx link state machine: 1: Disable, 0: Enable
    .CH1_MIN_IPG_CNT(1'b11), // minimum IPG to enforce
    .CH1_RX_DCO_CK_DIV(3'b000), // VCO output frequency divide by: 00x: x/1, 01x: x/2, 100: x/4, 101: x/8, 110: x/16, 111: x/32
    .CH1_RCV_DCC_EN(1'b0), // receiver coupling: 1: DC, 0: AC
    .CH1_RATE_MODE_RX(1'b0), // RX rate selection: 0: full rate, 1: half rate
    .CH1_RX_DIV11_SEL(1'b0), // RX rate selection SMPTE: 0: full rate, high definition SMPTE, 1: x/11 rate, standard definition SMPTE
    // CHx_SEL_SD_RX_CLK: FPGA bridge write clock and elastic buffer read clock driven by:
    .CH1_SEL_SD_RX_CLK(1'b1), // buffer driven by: 1: serdes recovered clock, 0: ff_ebrd_clk
    .CH1_FF_RX_H_CLK_EN(1'b0), // 1: enable, 0: disable
    .CH1_FF_RX_F_CLK_DIS(1'b0), // 1: disable, 0: enable
    .CH1_REQ_LVL_SET(2'b00), // level setting for equalization: 00: 6 dB, 01: 9 dB, 10: 12 dB, 11: not used
    .CH1_REQ_EN(1'b1), // receiver equalization: 1: enable, 0: disable
    .CH1_RTERM_RX(5'd19), // RX termination R ohm: 0: 5K, 1: 80, 4: 75, 6: 70, 11: 60, 19: 50, 25: 46, other: reserved
    .CH1_RXTERM_CM(2'b11), // Common mode voltage for RX input termination: 00: RX input supply, 01: Floating (AC Ground), 10: GND, 11: RX input supply
    // CHx_PDEN_SEL: this signal is used to disable the phase detector
    // in the CDR during electrical idle.
    // when set to 1 (enabled), checks if los is set.
    // If los is 0 then disables the phase detector (or data loop)
    .CH1_PDEN_SEL(1'b1), // 1: enable, 0: disable
    .CH1_RXIN_CM(2'b11), // Common mode for equalizer input in AC coupling: 00: 0.7V, 01: 0.65V, 10: 0.75V: 11: CMFB
    // CHx_LEQ_OFFSET: linear equalizer setting
    // this is used to selectively amplify high frequency components
    // more which are attenuated more on the backplane - similar to the
    // function performed by de-emphasis of the transmitter.
    // Four levels of equalization can be selected. ?
    .CH1_LEQ_OFFSET_SEL(1'b0), // ?
    .CH1_LEQ_OFFSET_TRIM(3'b000), // ?
    // CHx_RLOS_SEL: enables LOS detector output before enabling CDR
    // phase detector after calibration.
    .CH1_RX_LOS_LVL(3'b100), // Sets differential p-p threshold voltage for loss of signal detection
    .CH1_RX_LOS_CEQ(2'b11), // Sets the equalization value at input stage of LOS detector
    .CH1_RX_LOS_HYST_EN(1'b0), // Enables hysteresis in detection treshold level
    .CH1_RX_LOS_EN(1'b1), // Enables LOS of signal detector: 0: Disabled, 1: Enabled
    // enables boundary scan input path for routing the high speed RX
    // inputs to a lower speed Serdes in the FPGA (for out of band application)
    .CH1_LDR_RX2CORE_SEL(1'b0), // Low speed serial data RX: 1: Enabled, 0: Disabled (normal operation)

    // TX settings
    .CH1_TPWDNB(1'b1), // transmit channel power: 0: power down, 1: power up
    .CH1_INVERT_TX(1'b0), // transmitted data: 1: invert, 0: normal
    .CH1_SB_BYPASS(1'b0), // invert TX data after SerDes bridge; 1: invert, 0: normal (note: loopback data is inverted)
    .CH1_ENC_BYPASS(1'b1), // 1: bypass 8b10 encoder, 0: Normal operation
    .CH1_RATE_MODE_TX(1'b0), // rate selection for transmit: 1: full rate, 0: half rate
    // CHx_RTERM_TX: TX resistor termination select. Disabled when PCIe is enabled
    .CH1_RTERM_TX(5'd19), // TX termination R ohm: 0: 5K, 1: 80, 4: 75, 6: 70, 11: 60, 19: 50, 25: 46, other: reserved
    .CH1_TX_GEAR_BYPASS(1'b0), // PCS Tx gear box 1: bypass, 0: Normal operation
    .CH1_TX_GEAR_MODE(1'b0), // 2:1 gearing for trasmit path on selected channels: 1: enable, 0: disable (no gearing)
    .CH1_TX_CM_SEL(2'b00), // TX output common mode: 00: power down, 01: 0.6V, 10: 0.55V, 11: 0.5V
    .CH1_TDRV_PRE_EN(1'b0), // TX driver pre-emphasis: 1: enable, 0: disable
    .CH1_TDRV_POST_EN(1'b0), // TX driver post-emphasis: 1: enable, 0:disable
    .CH1_TX_PRE_SIGN(1'b0), // TX pre-emphasis sign: 1: not inverted, 0: inverted
    .CH1_TX_POST_SIGN(1'b0), // TX post-emphasis sign: 1: not inverted, 0: inverted
    .CH1_TDRV_SLICE0_SEL(2'b01), // TX drive slice enable for slice0: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    .CH1_TDRV_SLICE1_SEL(2'b00), // TX drive slice enable for slice1: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    .CH1_TDRV_SLICE2_SEL(2'b01), // TX drive slice enable for slice2: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    .CH1_TDRV_SLICE3_SEL(2'b01), // TX drive slice enable for slice3: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    .CH1_TDRV_SLICE4_SEL(2'b00), // TX drive slice enable for slice4: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    .CH1_TDRV_SLICE5_SEL(2'b00), // TX drive slice enable for slice5: 00: power down, 01: select main data, 10: select pre data, 11: select post data
    // TX driver slice current settings:
    // increases the output current of slice by 100 uA
    // which corresponds to 100 mV in output amplitude
    .CH1_TDRV_SLICE0_CUR(3'd3), // slice 0 swing uA: 0: 100, 1: 200, 2: 300, 3: 400, 4: 500, 5: 600, 6:700, 7:800
    .CH1_TDRV_SLICE1_CUR(3'd0), // slice 1 swing uA: 0: 100, 1: 200, 2: 300, 3: 400, 4: 500, 5: 600, 6:700, 7:800
    .CH1_TDRV_SLICE2_CUR(2'd3), // slice 2 swing uA: 0: 800, 1: 1600, 2: 2400, 3: 3200
    .CH1_TDRV_SLICE3_CUR(2'd2), // slice 3 swing uA: 0: 800, 1: 1600, 2: 2400, 3: 3200
    .CH1_TDRV_SLICE4_CUR(2'd0), // slice 4 swing uA: 0: 800, 1: 1600, 2: 2400, 3: 3200
    .CH1_TDRV_SLICE5_CUR(2'd0), // slice 5 swing uA: 0: 800, 1: 1600, 2: 2400, 3: 3200
    // CHx_TDRV_DAT_SEL: Driver output select
    // 00: Data from Serializer muxed to driver (normal operation)
    // 01: Data rate clock from Serializer muxed to driver
    // 10: Serial Rx to Tx LB (data) if slb_r2t_dat_en=1
    // 10: Serial Rx to Tx LB (clock) if slb_r2t_ck_en=1
    // 11: Serial LB from equalizer to driver if slb_eq2t_en=1
    .CH1_TDRV_DAT_SEL(2'b00),
    .CH1_TX_DIV11_SEL(1'b0), // TX rate selection SMPTE: 0: full rate, high definition SMPTE, 1: x/11 rate, standard definition SMPTE
    .CH1_FF_TX_H_CLK_EN(1'b0), // 1: enable, 0: disable
    .CH1_FF_TX_F_CLK_DIS(1'b0), // 1: disable, 0: enable
    //.CH1_CDR_MAX_RATE(2.5), // Receive max data rate (CDR)
    //.CH1_TXAMPLITUDE('d600), // TX amplitude in mV, acceptable values 100-1300 (steps of 20)
    //.CH1_TXDEPRE(DISABLED), // De-emphasis pre-cursor select: DISABLED, 0-11
    //.CH1_TXDEPOST(DISABLED), // De-emphasis post-cursor select: DISABLED, 0-11
    .CH1_PROTOCOL("8BSER"), // "8B10B", "G8B10B", "PCIe", "GbE", "SGMII", "XAUI", "SDI", "CPRI", "JESD204", "10BSER", "8BSER", "eDP"
    .CH1_CDR_CNT4SEL(2'b00), // ?
    .CH1_CDR_CNT8SEL(2'b00), // ?
    .CH1_DCOATDCFG(2'b00), // ?
    .CH1_DCOATDDLY(2'b00), // ?
    .CH1_DCOBYPSATD(1'b1), // ?
    .CH1_DCOCALDIV(3'b000), // ?
    .CH1_DCOCTLGI(3'b011), // ?
    .CH1_DCODISBDAVOID(1'b0), // ?
    .CH1_DCOFLTDAC(2'b00), // ?
    .CH1_DCOFTNRG(3'b001), // ?
    .CH1_DCOIOSTUNE(3'b010), // ?
    .CH1_DCOITUNE(2'b00), // ?
    .CH1_DCOITUNE4LSB(3'b010), // ?
    .CH1_DCOIUPDNX2(1'b1), // ?
    .CH1_DCONUOFLSB(3'b100), // ?
    .CH1_DCOSCALEI(2'b01), // ?
    .CH1_DCOSTARTVAL(3'b010), // ?
    .CH1_DCOSTEP(2'b11), // ?
    .CH1_BAND_THRESHOLD('d0), // ?
    .CH1_AUTO_FACQ_EN(1'b1), // ? reset signal to trigger the DCO frequency acquisition process when it's necessary
    .CH1_AUTO_CALIB_EN(1'b1), // ? reset signal to trigger the DCO calibration process when it's necessary
    .CH1_CALIB_CK_MODE(1'b0), // ?
    .CH1_REG_BAND_OFFSET('d0), // ?
    .CH1_REG_BAND_SEL('d0), // ?
    .CH1_REG_IDAC_SEL('d0), // ?
    .CH1_REG_IDAC_EN(1'b0), // ?
    .CH1_RX_RATE_SEL(4'd10), // Equalizer pole position select
    // enables to transmit slow data from FPGA core to serdes TX
    .CH1_LDR_CORE2TX_SEL(1'b0), // Low speed serial data TX: 1: Enabled, 0: Disabled (normal operation)
  )
  DCU0_inst
  (
    .D_REFCLKI(clk),
    .D_FFC_MACRO_RST(serdes_dual_rst),
    .D_FFC_MACROPDB(serdes_pdb),
    .D_FFC_TRST(tx_ser_rst),

    .CH0_HDINP(), .CH0_HDINN(),
    .CH0_HDOUTP(), .CH0_HDOUTN(),
    .CH0_FFC_FB_LOOPBACK(1'b0),
    .CH0_RX_REFCLK(clk),
    .CH0_FF_RXI_CLK(rx0_pclk), .CH0_FF_RX_PCLK(rx0_pclk),
    .CH0_FF_TXI_CLK(tx0_pclk), .CH0_FF_TX_PCLK(tx0_pclk),
    .CH0_FF_TX_D_0(txd[0]), .CH0_FF_TX_D_1(txd[1]),  .CH0_FF_TX_D_2(txd[2]),  .CH0_FF_TX_D_3(txd[3]),
    .CH0_FF_TX_D_4(txd[4]), .CH0_FF_TX_D_5(txd[5]),  .CH0_FF_TX_D_6(txd[6]),  .CH0_FF_TX_D_7(txd[7]),
    .CH0_FF_TX_D_8(comma),  .CH0_FF_TX_D_9(1'b0)  ,  .CH0_FF_TX_D_10(1'b0),   .CH0_FF_TX_D_11(1'b0),
    .CH0_FFC_EI_EN(1'b0), .CH0_FFC_SIGNAL_DETECT(1'b0), .CH0_FFC_LANE_TX_RST(tx_pcs_rst), .CH0_FFC_LANE_RX_RST(rx_pcs_rst),
    .CH0_FFC_RRST(rx_ser_rst), .CH0_FFC_TXPWDNB(tx_pwrup), .CH0_FFC_RXPWDNB(rx_pwrup), .D_FFC_DUAL_RST(dual_rst),
    .CH0_FF_RX_D_0(rxd0[0]), .CH0_FF_RX_D_1(rxd0[1]), .CH0_FF_RX_D_2(rxd0[2]), .CH0_FF_RX_D_3(rxd0[3]),
    .CH0_FF_RX_D_4(rxd0[4]), .CH0_FF_RX_D_5(rxd0[5]), .CH0_FF_RX_D_6(rxd0[6]), .CH0_FF_RX_D_7(rxd0[7]),
    .CH0_FFS_RLOS(rx0_los_lol), .CH0_FFS_RLOL(rx0_cdr_lol),

    .CH1_HDINP(), .CH1_HDINN(),
    .CH1_HDOUTP(), .CH1_HDOUTN(),
    .CH1_FFC_FB_LOOPBACK(1'b0),
    .CH1_RX_REFCLK(clk),
    .CH1_FF_RXI_CLK(rx1_pclk), .CH1_FF_RX_PCLK(rx1_pclk),
    .CH1_FF_TXI_CLK(tx1_pclk), .CH1_FF_TX_PCLK(tx1_pclk),
    .CH1_FF_TX_D_0(txd[0]), .CH1_FF_TX_D_1(txd[1]),  .CH1_FF_TX_D_2(txd[2]),  .CH1_FF_TX_D_3(txd[3]),
    .CH1_FF_TX_D_4(txd[4]), .CH1_FF_TX_D_5(txd[5]),  .CH1_FF_TX_D_6(txd[6]),  .CH1_FF_TX_D_7(txd[7]),
    .CH1_FF_TX_D_8(comma),  .CH1_FF_TX_D_9(1'b0)  ,  .CH1_FF_TX_D_10(1'b0),   .CH0_FF_TX_D_11(1'b0),
    .CH1_FFC_EI_EN(1'b0), .CH1_FFC_SIGNAL_DETECT(1'b0), .CH1_FFC_LANE_TX_RST(tx_pcs_rst), .CH1_FFC_LANE_RX_RST(rx_pcs_rst),
    .CH1_FFC_RRST(rx_ser_rst), .CH1_FFC_TXPWDNB(tx_pwrup), .CH1_FFC_RXPWDNB(rx_pwrup), .D_FFC_DUAL_RST(dual_rst),
    .CH1_FF_RX_D_0(rxd1[0]), .CH1_FF_RX_D_1(rxd1[1]), .CH1_FF_RX_D_2(rxd1[2]), .CH1_FF_RX_D_3(rxd1[3]),
    .CH1_FF_RX_D_4(rxd1[4]), .CH1_FF_RX_D_5(rxd1[5]), .CH1_FF_RX_D_6(rxd1[6]), .CH1_FF_RX_D_7(rxd1[7]),
    .CH1_FFS_RLOS(rx1_los_lol), .CH1_FFS_RLOL(rx1_cdr_lol)
  );

  // blink counters for clocks going out of serdes module
  reg [27:0] rx0_hb, tx0_hb;
  reg [27:0] rx1_hb, tx1_hb;
  
  always @(posedge tx0_pclk) tx0_hb <= tx0_hb + 1'b1;
  always @(posedge rx0_pclk) rx0_hb <= rx0_hb + 1'b1;
  always @(posedge tx1_pclk) tx1_hb <= tx1_hb + 1'b1;
  always @(posedge rx1_pclk) rx1_hb <= rx1_hb + 1'b1;
  
  assign disp0 = {rx0_los_lol, rx0_cdr_lol, tx0_hb[27], rx0_hb[27]};
  assign disp1 = {rx1_los_lol, rx1_cdr_lol, tx1_hb[27], rx1_hb[27]};

endmodule
