// BTN debouncer and signal generator for
// dynamic phase shift control
module btn_ecp5pll_phase
#(
  parameter c_debounce_bits = 16
)
(
  input  clk,         // 1-100 MHz
  input  inc, dec,    // BTNs
  output [7:0] phase, // counter for display
  output phasedir, phasestep, phaseloadreg
);
  reg [c_debounce_bits-1:0] R_debounce;
  reg  [1:0] R_btn, R_btn_prev;
  reg        R_new;
  always @(posedge clk)
  begin
    if(R_debounce[c_debounce_bits-1])
    begin
      if(R_btn != R_btn_prev)
      begin
        R_debounce <= 0;
        R_new <= 1;
      end
      R_btn[1] <= inc;
      R_btn[0] <= dec;
      R_btn_prev <= R_btn;
    end
    else
    begin
      R_debounce <= R_debounce + 1;
      R_new <= 0;
    end
  end
  wire S_inc = R_btn[1];
  wire S_dec = R_btn[0];

  reg R_phasedir, R_phasestep, R_phasestep_early;
  always @(posedge clk)
  begin
    if(R_new)
    begin
      R_phasedir        <= S_inc | S_dec ? S_inc : R_phasedir;
      R_phasestep_early <= S_inc | S_dec;
    end
    // phasedir must be stable 5ns before phasestep is pulsed
    R_phasestep <= R_phasestep_early;
  end
  assign phasedir     = R_phasedir;
  assign phasestep    = R_phasestep;
  assign phaseloadreg = 1'b0; // TODO support it
  
  reg [7:0] R_phase = 0;
  always @(posedge clk)
  begin
    if(R_phasestep_early == 1 && R_phasestep == 0)
      R_phase <= R_phasedir ? R_phase + 1 : R_phase - 1;
  end
  assign phase = R_phase; // for display
endmodule
