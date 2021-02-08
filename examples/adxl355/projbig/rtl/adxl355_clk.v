// clock generator for ADXL355 accelerometer

`default_nettype none
module adxl355_clk
#(
  clk_out0_hz  = 40*1000000, // Hz, 40 MHz, PLL internal clock divisible by 512 to make 2*clk_adxl_hz=2048 kHz
  clk_pps_hz   = 1,          // Hz, 1 Hz, TODO not used
  clk_adxl_hz  = 1024*1000,  // Hz, 1024 kHz, LUT-generated adxl clock
  clk_sync_hz  = 1000,       // Hz, 1 kHz SYNC clock, sample rate
  clk_sync_pulse_bits = 5,   // 2**(n-1)/2048kHz pulse width of SYNC clock minimal: 4->3.91us, reliable: 5->7.81us
  pa_sync_bits = 24          // SYNC phase accumulator bits
)
(
  input  i_clk,      // 40 kHz system clock
  input  i_pps,      // 1 Hz pulse per second from GPS TODO not used
  output o_clk_adxl, // 1024 kHz
  output o_clk_sync  // 1 kHz
);
  localparam divider1024kHz=clk_out0_hz*2/clk_adxl_hz; // default 78125 for half-period 2048 kHz from 40 MHz
  reg clk_sync; // 1.024kHz, must become 1 cca 25ns (1 clk cycle) before clk_adxl and keep 1 for at least 4 clk cycles
  reg clk_adxl; // 1024 kHz, toggle reg
  reg [$clog2(divider1024kHz)-1:0] clk_adxl_cnt; // divider counter for 1024 kHz
  reg [pa_sync_bits-1:0] pa_sync; // phase accumulator for sync signal
  localparam real re_pa_inc = 2.0 * clk_sync_hz * 2**pa_sync_bits / clk_adxl_hz; // default 32768 for 1kHz sample rate
  reg [pa_sync_bits-1:0] int_pa_inc = re_pa_inc; // sample rate frequency fine adjust reg implicit real->integer
  wire [pa_sync_bits:0] pa_sync_next = pa_sync + int_pa_inc; // one bit more for carry
  reg [clk_sync_pulse_bits-1:0] cnt_sync_fall;
  wire clk2048kHz = clk_adxl_cnt == divider1024kHz-1 ? 1 : 0;
  localparam clk_25ns_bits = 2;
  reg [clk_25ns_bits-1:0] clk_adxl_25ns; // 25ns step delay shift register
  reg [clk_25ns_bits-1:0] clk_sync_25ns; // 25ns step delay shift register
  always @(posedge i_clk)
  begin
    if(clk2048kHz) 
    begin // 2048 kHz execution
      clk_adxl_cnt <= 0;
      clk_adxl <= ~clk_adxl; // 1024 kHz toggle
      pa_sync <= pa_sync_next; // changes value 50 ns before clk_adxl edge
      if(pa_sync_next[pa_sync_bits]) // carry set
      begin // 1 kHz execution
        clk_sync <= 1; // changes value 25 ns before clk_adxl_cnt, required setup time
        cnt_sync_fall <= 0; // counts up to MSB set
      end
      else // counter to delay turn off
      begin
        if(cnt_sync_fall[clk_sync_pulse_bits-1]) // MSB set, minimum pulse width should be 4x 1024kHz cycles = 3.91us, count 8 should be 2x more than required
          clk_sync <= 0; // turn off clk_sync
        else
          cnt_sync_fall <= cnt_sync_fall+1;
      end
    end
    else
      clk_adxl_cnt <= clk_adxl_cnt+1;
    clk_adxl_25ns <= { clk_adxl_25ns[clk_25ns_bits-2:0], clk_adxl };
    clk_sync_25ns <= { clk_sync_25ns[clk_25ns_bits-2:0], clk_sync };
  end
  assign o_clk_adxl = clk_adxl_25ns[1]; // 1024 kHz, n*25ns delayed
  assign o_clk_sync = clk_sync_25ns[0]; // 1 kHz, n*25ns delayed

endmodule
`default_nettype wire
