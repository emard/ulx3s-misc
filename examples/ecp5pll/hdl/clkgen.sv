// (c)EMARD
// License=BSD

// unfinished parametric ECP5 PLL generator

module clkgen
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

  function integer abs(x);
    abs = x > 0 ? x : -x;
  endfunction

  function integer F_ecp5pll(input integer x);
    // integer sfreq [3:0]; // array not supported?
    integer input_div, input_div_min, input_div_max;
    integer output_div, output_div_min, output_div_max;
    integer feedback_div;
    integer fpfd, fvco, fout;
    integer error;
    integer phase_compensation;
    integer phase_count_x8;
    integer phase_shift;

    integer params_fvco           ;
    integer params_refclk_div     ;
    integer params_feedback_div   ;
    integer params_output_div     ;
    integer params_fin_string     ;
    integer params_fout_string    ;
    integer params_fout           ;
    integer params_fvco           ;
    integer params_primary_cphase ;
    integer params_primary_fphase ;

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
      for(feedback_div = 1; feedback_div <= 128; feedback_div=feedback_div+1)
      begin
        output_div_min = VCO_MIN/feedback_div/fpfd;
        if(output_div_min < 1)
          output_div_min = 1;
        output_div_max = VCO_MAX/feedback_div/fpfd;
        if(output_div_max > 128)
          output_div_max = 128;
        for(output_div = output_div_min; output_div <= output_div_max; output_div=output_div+1)
        begin
          fvco = fpfd * feedback_div * output_div;
          fout = fvco / output_div;
          if( abs(fout-out0_hz) < error
          || (fout==out0_hz && abs(fvco-VCO_OPTIMAL) < abs(params_fvco-VCO_OPTIMAL)) )
          begin
            error = abs(fout-out0_hz);
            phase_compensation     = (output_div+1)/2*8-8+output_div/2*8; // output_div/2*8 = 180 deg shift
            phase_count_x8         = phase_compensation + 8*output_div*out0_deg/360;
            if(phase_count_x8 > 1023)
              phase_count_x8 = phase_count_x8 % (output_div*8); // wraparound 360 deg
            params_refclk_div      = input_div;
            params_feedback_div    = feedback_div;
            params_output_div      = output_div;
            //params_fin_string      = Hz2MHz_str(in_hz);
            //params_fout_string     = Hz2MHz_str(fout);
            params_fout            = fout;
            params_fvco            = fvco;
            params_primary_cphase  = phase_count_x8 / 8;
            params_primary_fphase  = phase_count_x8 % 8;
          end
        end
      end
    end

    F_ecp5pll = x;
  endfunction

  localparam y = F_ecp5pll(0);

  assign clk_o = {4{clk_i}};

endmodule
