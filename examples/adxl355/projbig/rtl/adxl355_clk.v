// clock generator for ADXL355 accelerometer

`default_nettype none
module adxl355_clk
#(
  clk_out0_hz  = 40*1000000, // Hz, 40 MHz, PLL internal clock
  pps_hz       = 1,          // Hz, 1 Hz when pps_s = 1
  pps_s        = 1,          // s, 1 s when pps_hz = 1
  pps_tol_us   = 500,        // us, 500 us, PPS input +-tolerance
  clk_sync_hz  = 1000,       // Hz, 1 kHz SYNC clock, sample rate
  clk_sync_pulse_bits = 9,   // 2**(n-1)/clk_out0_hz s pulse width of SYNC clock minimal: 3.91us, reliable: 9->6.4us
  pa_sync_bits = 32          // SYNC phase accumulator bits
)
(
  input  i_clk,       // 40 kHz system clock
  input  i_pps,       // 1 Hz pulse per second from GPS TODO not used
  output o_pps_valid, // 1 when pps in +-clk_pps_tol_us
  output o_clk_sync   // 1 kHz
);
  localparam real re_pa_inc = 1.0 * clk_sync_hz * 2.0 * 2**(pa_sync_bits-1) / clk_out0_hz;
  localparam integer int_pa_inc = re_pa_inc; // 107374 for 1kHz
  reg [pa_sync_bits-1:0] reg_pa_inc = int_pa_inc; // sample rate frequency fine adjust reg implicit real->integer
  reg [pa_sync_bits-1:0] pa_sync; // phase accumulator for sync signal
  wire [pa_sync_bits-1:0] pa_sync_next = pa_sync + reg_pa_inc; // one bit more for carry
  always @(posedge i_clk)
    pa_sync <= pa_sync_next;
  assign o_clk_sync = pa_sync[pa_sync_bits-1]; // 1 kHz

  // check PPS for tolerance
  localparam real re_pps_min_cnt = 1.0 * clk_out0_hz*pps_s/pps_hz - 1.0 * pps_tol_us*clk_out0_hz/1000000;
  localparam real re_pps_max_cnt = 1.0 * clk_out0_hz*pps_s/pps_hz + 1.0 * pps_tol_us*clk_out0_hz/1000000;
  localparam integer pps_min_cnt = re_pps_min_cnt;
  localparam integer pps_max_cnt = re_pps_max_cnt;
  localparam cnt_pps_bits = 32;
  reg [cnt_pps_bits-1:0] cnt_pps, cnt_pps_prev;
  reg [1:0] pps_shift; // for PPS edge detection
  reg pps_valid_tmp, pps_valid;
  wire cnt_pps_min = cnt_pps == pps_min_cnt;
  wire cnt_pps_max = cnt_pps == pps_max_cnt;
  always @(posedge i_clk)
  begin
    pps_shift <= {i_pps, pps_shift[1]};
    if(pps_shift == 2'b10 || cnt_pps_max == 1) // rising edge of PPS or PPS too late
    begin
      pps_valid <= cnt_pps_max ? 0 : pps_valid_tmp;
      cnt_pps_prev <= cnt_pps;
      cnt_pps <= 0;
    end
    else
      cnt_pps <= cnt_pps + 1;

    if(cnt_pps_min)
      pps_valid_tmp <= 1;
    else
    begin
      if(cnt_pps_max == 1 || cnt_pps == 0)
        pps_valid_tmp <= 0;
    end
  end
  assign o_pps_valid = pps_valid;
endmodule
`default_nettype wire
