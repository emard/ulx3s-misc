// (c)EMARD
// License=BSD

// parametric ECP5 PLL generator in systemverilog
// to see actual frequencies
// trellis log/stdout : search for "MHz", "Derived", "frequency"
// to see actual phase shifts
// diamond log/*.mrp  : search for "Phase", "Desired"

module ecp5pll
#(
  parameter integer in_hz      =  25000000,
  parameter integer out0_hz    =  25000000,
  parameter integer out0_deg   =         0, // keep 0
  parameter integer out1_hz    =  25000000,
  parameter integer out1_deg   =         0,
  parameter integer out2_hz    =  25000000,
  parameter integer out2_deg   =         0,
  parameter integer out3_hz    =  25000000,
  parameter integer out3_deg   =         0,
  parameter integer reset_en   =         0,
  parameter integer standby_en =         0,
  parameter integer dynamic_en =         0
)
(
  input        clk_i,
  output [3:0] clk_o,
  input        reset,
  input        standby,
  input  [1:0] phasesel,
  input        phasedir, phasestep, phaseloadreg,
  output       locked
);

  localparam PFD_MIN =   3125000;
  localparam PFD_MAX = 400000000;
  localparam VCO_MIN = 400000000;
  localparam VCO_MAX = 800000000;
  localparam VCO_OPTIMAL = (VCO_MIN+VCO_MAX)/2;

  function enabled_str(input integer en);
    enabled_str = en == 0 ? "DISABLED" : "ENABLED";
  endfunction

  function integer abs(input integer x);
    abs = x > 0 ? x : -x;
  endfunction

  function integer F_ecp5pll(input integer x);
    integer input_div, input_div_min, input_div_max;
    integer output_div, output_div_min, output_div_max;
    integer feedback_div;
    integer fpfd, fvco, fout;
    integer error;
    integer phase_compensation;
    integer phase_count_x8;
    integer phase_shift;

    integer params_refclk_div       ;
    integer params_feedback_div     ;
    integer params_output_div       ;
    integer params_primary_phase_x8 ;
    integer params_fvco             ;

    params_fvco = 0;
    error = 999999999;
    input_div_min = in_hz/PFD_MAX;
    if(input_div_min < 1)
      input_div_min = 1;
    input_div_max = in_hz/PFD_MIN;
    if(input_div_max > 128)
      input_div_max = 128;
    for(input_div = input_div_min; input_div <= input_div_max; input_div=input_div+1)
    begin
      fpfd = in_hz / input_div;
      for(feedback_div = 1; feedback_div <= 80; feedback_div=feedback_div+1)
      begin
	fout = fpfd * feedback_div;
        output_div_min = VCO_MIN/fout;
        if(output_div_min < 1)
          output_div_min = 1;
        output_div_max = VCO_MAX/fout;
        if(output_div_max > 128)
          output_div_max = 128;
        for(output_div = output_div_min; output_div <= output_div_max; output_div=output_div+1)
        begin
          fvco = fout * output_div;
          if( abs(fout-out0_hz) < error
          || (fout==out0_hz && abs(fvco-VCO_OPTIMAL) < abs(params_fvco-VCO_OPTIMAL)) )
          begin
            error                   = abs(fout-out0_hz);
            phase_compensation      = (output_div+1)/2*8-8+output_div/2*8; // output_div/2*8 = 180 deg shift
            phase_count_x8          = phase_compensation + 8*output_div*out0_deg/360;
            if(phase_count_x8 > 1023)
              phase_count_x8 = phase_count_x8 % (output_div*8); // wraparound 360 deg
            params_refclk_div       = input_div;
            params_feedback_div     = feedback_div;
            params_output_div       = output_div;
            params_primary_phase_x8 = phase_count_x8;
            params_fvco             = fvco;
          end
        end
      end
    end
    // FIXME in the future when yosys supports struct
    if(x==0)
      F_ecp5pll = params_refclk_div;
    if(x==1)
      F_ecp5pll = params_feedback_div;
    if(x==2)
      F_ecp5pll = params_output_div;
    if(x==3)
      F_ecp5pll = params_primary_phase_x8;
  endfunction

  // FIXME it is inefficient to call F_ecp5pll multiple times
  localparam params_refclk_div       = F_ecp5pll(0);
  localparam params_feedback_div     = F_ecp5pll(1);
  localparam params_output_div       = F_ecp5pll(2);
  localparam params_primary_phase_x8 = F_ecp5pll(3);
  localparam params_primary_cphase   = params_primary_phase_x8 / 8;
  localparam params_primary_fphase   = params_primary_phase_x8 % 8;
  localparam params_fout             = in_hz / params_refclk_div * params_feedback_div;
  localparam params_fvco             = params_fout * params_output_div;

  function integer F_secondary(input integer sfreq, sphase, x);
    integer div, freq;
    integer phase_compensation, phase_count_x8;

    div = params_fvco/sfreq;
    freq = params_fvco/div;
    phase_compensation = div*8-8;
    phase_count_x8 = phase_compensation + 8*div*sphase/360;
    if(phase_count_x8 > 1023)
      phase_count_x8 = phase_count_x8 % (div*8); // wraparound 360 deg

    if(x==0)
      F_secondary = div;
    if(x==1)
      F_secondary = phase_count_x8;
  endfunction

  localparam params_secondary1_div      = F_secondary(out1_hz, out1_deg, 0);
  localparam params_secondary1_cphase   = F_secondary(out1_hz, out1_deg, 1) / 8;
  localparam params_secondary1_fphase   = F_secondary(out1_hz, out1_deg, 1) % 8;
  localparam params_secondary2_div      = F_secondary(out2_hz, out2_deg, 0);
  localparam params_secondary2_cphase   = F_secondary(out2_hz, out2_deg, 1) / 8;
  localparam params_secondary2_fphase   = F_secondary(out2_hz, out2_deg, 1) % 8;
  localparam params_secondary3_div      = F_secondary(out3_hz, out3_deg, 0);
  localparam params_secondary3_cphase   = F_secondary(out3_hz, out3_deg, 1) / 8;
  localparam params_secondary3_fphase   = F_secondary(out3_hz, out3_deg, 1) % 8;

  wire [1:0] phasesel_hw = phasesel-1;
  wire CLKOP; // internal

  // TODO: frequencies in MHz passed as "attributes"
  // should appear in diamond *.mrp file like "Output Clock(P) Frequency (MHz):"
  // (* FREQUENCY_PIN_CLKI="025.000000" *)
  // (* FREQUENCY_PIN_CLKOP="023.345678" *)
  // (* FREQUENCY_PIN_CLKOS="034.234567" *)
  // (* FREQUENCY_PIN_CLKOS2="111.345678" *)
  // (* FREQUENCY_PIN_CLKOS3="123.456789" *)
  (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
  EHXPLLL
  #(
    .CLKI_DIV     (params_refclk_div),
    .CLKFB_DIV    (params_feedback_div),
    .FEEDBK_PATH  ("CLKOP"),

    .OUTDIVIDER_MUXA("DIVA"),
    .CLKOP_ENABLE ("ENABLED"),
    .CLKOP_DIV    (params_output_div),
    .CLKOP_CPHASE (params_primary_cphase),
    .CLKOP_FPHASE (params_primary_fphase),

    .OUTDIVIDER_MUXB("DIVB"),
    .CLKOS_ENABLE ("ENABLED"),
    .CLKOS_DIV    (params_secondary1_div),
    .CLKOS_CPHASE (params_secondary1_cphase),
    .CLKOS_FPHASE (params_secondary1_fphase),

    .OUTDIVIDER_MUXC("DIVC"),
    .CLKOS2_ENABLE("ENABLED"),
    .CLKOS2_DIV   (params_secondary2_div),
    .CLKOS2_CPHASE(params_secondary2_cphase),
    .CLKOS2_FPHASE(params_secondary2_fphase),

    .OUTDIVIDER_MUXD("DIVD"),
    .CLKOS3_ENABLE("ENABLED"),
    .CLKOS3_DIV   (params_secondary3_div),
    .CLKOS3_CPHASE(params_secondary3_cphase),
    .CLKOS3_FPHASE(params_secondary3_fphase),

    .INTFB_WAKE   ("DISABLED"),
    .STDBY_ENABLE (enabled_str(standby_en)),
    .PLLRST_ENA   (enabled_str(reset_en)),
    .DPHASE_SOURCE(enabled_str(dynamic_en)),
    .PLL_LOCK_MODE(0)
  )
  pll_inst
  (
    .RST(1'b0),
    .STDBY(1'b0),
    .CLKI(clk_i),
    .CLKOP(CLKOP),
    .CLKOS (clk_o[1]),
    .CLKOS2(clk_o[2]),
    .CLKOS3(clk_o[3]),
    .CLKFB(CLKOP),
    .CLKINTFB(),
    .PHASESEL1(phasesel_hw[1]),
    .PHASESEL0(phasesel_hw[0]),
    .PHASEDIR(phasedir),
    .PHASESTEP(phasestep),
    .PHASELOADREG(phaseloadreg),
    .PLLWAKESYNC(1'b0),
    .ENCLKOP(1'b0),
    .LOCK(locked)
  );
  assign clk_o[0] = CLKOP;

endmodule
