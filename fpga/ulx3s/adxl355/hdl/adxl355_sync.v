// sync generator for ADXL355 accelerometer

// 1. adjusts PA increment up/down to keep required sample count between PPS
// 2. when same sample count between PPS, lock phase by maintaining same captured PA value at each PPS pulse
// PA = phase accumulator
// during first few minutes it can bounce few times
// between 1/4 and 3/4 phase and it should lock around 1/2 phase
// 1 phase = 360 deg

`default_nettype none
module adxl355_sync
#(
  clk_out0_hz  = 40*1000000, // Hz, 40 MHz, PLL internal clock
  pps_n        = 1,          // n, 1 Hz when pps_s = 1 number of PPS pulse per time interval
  pps_s        = 1,          // s, 1 s when pps_n = 1 time interval of PPS pulses
  pps_tol_us   = 500,        // us, 500 us, PPS input +-tolerance
  clk_sync_hz  = 1000,       // Hz, 1 kHz SYNC clock, sample rate
  pa_limit_ppm = 1000,       // 1/1e6 phase accumulator +- limit range of PA inc
  pa_corr_step = 1,          // PA coarse correction step (experimentally adjust), more->larger steps
  pa_sync_bits = 32          // SYNC phase accumulator bits, less->faster convergence, more->smaller jitter
)
(
  input  i_clk,       // 40 kHz system clock
  input  i_pps,       // 1 Hz pulse per second from GPS TODO not used
  output [7:0] o_cnt, // debug output sample counter captured each rising edge of PPS
  output o_pps_valid, // 1 when pps in +-clk_pps_tol_us
  output o_locked,    // 1 when sync makes required number of samples between PPS pulses
  output o_clk_sync   // 1 kHz
);
  reg fine1up0dn = 0;
  localparam real re_pa_inc = 1.0 * clk_sync_hz * 2**16 * 2**(pa_sync_bits-16) / clk_out0_hz; // 2**16 separated to avoid 32-bit signed overflow
  localparam integer int_pa_inc = re_pa_inc; // 107374 for 1kHz
  wire [pa_sync_bits-1:0] pa_inc_min = int_pa_inc - int_pa_inc*pa_limit_ppm/1000000; // phase accumulator min limit
  wire [pa_sync_bits-1:0] pa_inc_max = int_pa_inc + int_pa_inc*pa_limit_ppm/1000000; // phase accumulator max limit
  reg [pa_sync_bits-1:0] reg_pa_inc = int_pa_inc; // sample rate frequency adjust reg implicit real->integer
  reg [pa_sync_bits-1:0] pa_sync; // phase accumulator for sync signal
  wire [pa_sync_bits-1:0] pa_sync_next = fine1up0dn ? pa_sync + reg_pa_inc + 1 : pa_sync + reg_pa_inc;
  always @(posedge i_clk)
  begin
    pa_sync <= pa_sync_next;
  end
  assign o_clk_sync = pa_sync[pa_sync_bits-1]; // 1 kHz

  // rising edge detection of sync
  reg [1:0] sync_shift;
  always @(posedge i_clk)
    sync_shift <= {pa_sync[pa_sync_bits-1], sync_shift[1]};
  wire sync_rising = sync_shift == 2'b10; // rising edge detection of pa_sync MSB bit
  wire sync_falling = sync_shift == 2'b01; // falling edge detection of pa_sync MSB bit

  // check PPS for tolerance
  localparam real re_pps_min_cnt = 1.0 * clk_out0_hz*pps_s/pps_n - 1.0 * pps_tol_us*clk_out0_hz/1000000;
  localparam real re_pps_max_cnt = 1.0 * clk_out0_hz*pps_s/pps_n + 1.0 * pps_tol_us*clk_out0_hz/1000000;
  localparam integer pps_min_cnt = re_pps_min_cnt;
  localparam integer pps_max_cnt = re_pps_max_cnt;
  localparam cnt_pps_bits = 32;
  reg [cnt_pps_bits-1:0] cnt_pps;
  wire cnt_pps_min = cnt_pps == pps_min_cnt;
  wire cnt_pps_max = cnt_pps == pps_max_cnt;
  reg [1:0] pps_shift; // for PPS edge detection
  reg pps_valid_tmp, pps_valid;
  wire pps_rising = pps_shift == 2'b10;
  always @(posedge i_clk)
  begin
    pps_shift <= {i_pps, pps_shift[1]};
    if(pps_rising || cnt_pps_max) // rising edge of PPS or PPS too late
    begin
      pps_valid <= cnt_pps_max ? 0 : pps_valid_tmp;
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

  // rising edge detection of PPS valid signal
  reg [1:0] pps_valid_shift;
  always @(posedge i_clk)
    pps_valid_shift <= {pps_valid, pps_valid_shift[1]};
  wire pps_valid_rising = pps_valid_shift == 2'b10;

  // sawtooth sample counter, reset period ideally should match PPS signal
  // capture at each PPS signal should result in the same cnt_sample_pps value
  localparam cnt_sample_pps_n = clk_sync_hz*pps_s/pps_n; // n of samples per PPS period
  localparam cnt_sample_pps_bits = $clog2(cnt_sample_pps_n-1);
  reg [cnt_sample_pps_bits-1:0] cnt_sample_pps = 0; // sample counter
  always @(posedge i_clk)
  begin
    if(sync_falling)
    begin
      if(cnt_sample_pps == cnt_sample_pps_n-1)
        cnt_sample_pps <= 0;
      else
        cnt_sample_pps <= cnt_sample_pps + 1;
    end
  end

  // capture sample-counter value at PPS rising edge
  reg [cnt_sample_pps_bits-1:0] cnt_sample_pps_capture, cnt_sample_pps_capture_prev;
  reg [cnt_sample_pps_bits-1:0] cnt_difference;
  reg [pa_sync_bits-1:0] pa_sync_capture;
  reg faster, slower;
  reg locked;
  always @(posedge i_clk)
  begin
    if(pps_valid)
    begin // PPS valid
      if(pps_rising)
      begin // PPS rising
        pa_sync_capture <= pa_sync;
        cnt_sample_pps_capture_prev <= cnt_sample_pps_capture;
        cnt_sample_pps_capture <= cnt_sample_pps;
        if(cnt_difference == 0)
        begin
          locked <= 1;
          // at the edges of phase stability, change reg_pa_inc
          faster <= pa_sync[pa_sync_bits-1:pa_sync_bits-2] == 3'b00; // if PA < 1/4, faster
          slower <= pa_sync[pa_sync_bits-1:pa_sync_bits-2] == 3'b11; // if PA > 3/4, slower
          // cnt_difference zero, fine freq adjustment
          // tight lock, keep PA around 1/2, away from falling edge of sync at 0
          // PA value is used to lock the phase
          if(pa_sync[pa_sync_bits-1]) // if PA > 1/2
            fine1up0dn <= 0; // PA > 1/2 -> fine dec
          else
            fine1up0dn <= 1; // PA < 1/2 -> fine inc
          // when locked, pa_sync should fluctuate around 1/2
        end
        else
        begin
          locked <= 0;
          // cnt_difference nonzero, coarse freq adjustment
          //if(cnt_difference==1 || cnt_difference==-1) // -1 or +1 exactly, more LUTs
          if(cnt_difference[cnt_sample_pps_bits-1] || cnt_difference[0]) // simplified -1 or +1, glitches possible and hopefully tolerated
          begin
            faster <=  cnt_difference[cnt_sample_pps_bits-1]; // negative -> faster
            slower <= ~cnt_difference[cnt_sample_pps_bits-1]; // positive -> slower
            //cnt_correct_prev <= cnt_correct;
            //cnt_correct <= 0;
          end
          else
          begin
            faster <= 0;
            slower <= 0;
          end
        end
      end // PPS rising
      else // PPS not rising
      begin
        faster <= 0;
        slower <= 0;
      end
    end // PPS valid
    else // PPS not valid
    begin
      faster <= 0;
      slower <= 0;
      locked <= 0;
    end // PPS not valid
    cnt_difference <= cnt_sample_pps_capture - cnt_sample_pps_capture_prev;
  end
  assign o_locked = locked;

  // debug
  //assign o_cnt = cnt_sample_pps_capture; // show sample number captured at PPS (coarse)
  //assign o_cnt = reg_pa_inc[7:0]; // show PA increment
  assign o_cnt = pa_sync_capture[pa_sync_bits-1:pa_sync_bits-8]; // show PA value captured at PPS (fine)
  //assign o_cnt = pa_sync[pa_sync_bits-1:pa_sync_bits-8]; // show current PA value
  
  // control faster/slower reg_pa_inc
  always @(posedge i_clk)
  begin
    if(faster && ~slower)
    begin
      if(reg_pa_inc < pa_inc_max)
        reg_pa_inc <= reg_pa_inc + pa_corr_step; // run faster
    end
    else
      if(slower && ~faster)
      begin
        if(reg_pa_inc > pa_inc_min)
          reg_pa_inc <= reg_pa_inc - pa_corr_step; // run slower
      end
  end

  // debug
  //assign o_cnt = cnt_difference;
  //assign o_cnt = cnt_correct_prev; // index to pa_inc correction
  //assign o_cnt = pa_corr_step; // correction value

endmodule
`default_nettype wire
