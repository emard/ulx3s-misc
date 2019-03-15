module clk_25m_287m5_19m17
(
  input CLKI, // 25
  output CLKOP, // clk_287M5Hz,
  output CLKOS, // clk_19M166Hz,
  output LOCKED
);
    wire int_locked;

    (* ICP_CURRENT="5" *) (* LPF_RESISTOR="16" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
    EHXPLLL
    #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .CLKOS_FPHASE(0),
        .CLKOP_FPHASE(0),
        .CLKOS3_CPHASE(0),
        .CLKOS2_CPHASE(0),
        .CLKOS_CPHASE(29),
        .CLKOP_CPHASE(1),
        .OUTDIVIDER_MUXD("DIVD"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXA("DIVA"),
        .CLKOS3_ENABLE("DISABLED"),
        .CLKOS2_ENABLE("DISABLED"),
        .CLKOS_ENABLE("ENABLED"),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOS3_DIV(1),
        .CLKOS2_DIV(1),
        .CLKOS_DIV(30),
        .CLKOP_DIV(2),
        .CLKFB_DIV(23),
        .CLKI_DIV(2),
        .FEEDBK_PATH("CLKOP")
    )
    pll_i
    (
        .CLKI(CLKI), // 25 MHz
        .CLKFB(CLKOP),
        .CLKOP(CLKOP), // 287.5 MHz
        .CLKOS(CLKOS), // 19.166 MHz
        //.CLKOS2(clk_25MHz), 
        //.CLKOS3(clk_83M333Hz),
        .RST(1'b0),
        .STDBY(1'b0),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b0),
        .PHASESTEP(1'b0),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .ENCLKOS(1'b0),
        .ENCLKOS2(1'b0),
        .ENCLKOS3(1'b0),
        .LOCK(LOCKED),
        .INTLOCK(int_locked)
    );
endmodule

