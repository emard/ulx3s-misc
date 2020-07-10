//
// sdram.v
//
// This code is public domain
//

module sdram (
  input             clk100_mhz,     // sdram is accessed at 100MHz
  
  // interface to the MT48LC16M16 chip
  inout      [15:0] sd_data,    // 16 bit databus
  output reg [12:0] sd_addr,    // 13 bit multiplexed address bus
  output reg  [1:0] sd_dqm,     // two byte masks
  output reg  [1:0] sd_ba,      // two banks
  output            sd_cs,      // chip select
  output 	    sd_we,      // write enable
  output            sd_ras,     // row address select
  output            sd_cas,     // columns address select
  output reg        sd_cke,     // clock enable
  output            sd_clk,     // chip clock (inverted from input clk)

  // M68K interface
  input      [15:0] din,        // data input from cpu
  output reg [15:0] dout,       // data output to cpu
  input      [23:0] addr,       // 24 bit word address
  input             udsn,       // upper data strobe
  input             ldsn,       // lower data strobe
  input             asn,        // address strobe
  input             rw,         // cpu/chipset requests write
  input             rst         // cpu reset
);

  localparam RASCAS_DELAY   = 3'd2;   // tRCD=20ns -> 2 cycles is just enough @ 100MHz
  localparam BURST_LENGTH   = 3'b001; // 000=1, 001=2, 010=4, 011=8
  localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
  localparam CAS_LATENCY    = 3'd3;   // 2/3 allowed
  localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
  localparam NO_WRITE_BURST = 1'b1;   // 0=write burst enabled, 1=only single access write

  localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

  // ---------------------------------------------------------------------
  // ------------------------ cycle state machine ------------------------
  // ---------------------------------------------------------------------

  // The state machine runs at 100Mhz, asynchronous from the CPU

  localparam STATE_FIRST     = 3'd0;   // idle state, prep command
  localparam STATE_CMD_CAS   = STATE_FIRST  + RASCAS_DELAY; // prep CAS cycle
  localparam STATE_READ      = STATE_CMD_CAS + CAS_LATENCY + 3'd1;
  localparam STATE_LAST      = STATE_READ + 3'd1;

  reg [2:0] t;

  // ---------------------------------------------------------------------
  // --------------------------- startup/reset ---------------------------
  // ---------------------------------------------------------------------

  // make sure rst lasts long enough (recommended 100us)
  reg [4:0] reset;
  always @(posedge clk100_mhz) begin
    reset <= (|reset) ? reset - 5'd1 : 0;
    if(rst)	reset <= 5'd25;
  end

  // ---------------------------------------------------------------------
  // ------------------ generate ram control signals ---------------------
  // ---------------------------------------------------------------------

  // all possible commands
  localparam CMD_INHIBIT         = 4'b1111;
  localparam CMD_NOP             = 4'b0111;
  localparam CMD_ACTIVE          = 4'b0011;
  localparam CMD_READ            = 4'b0101;
  localparam CMD_WRITE           = 4'b0100;
  localparam CMD_BURST_TERMINATE = 4'b0110;
  localparam CMD_PRECHARGE       = 4'b0010;
  localparam CMD_AUTO_REFRESH    = 4'b0001;
  localparam CMD_LOAD_MODE       = 4'b0000;

  reg  [3:0] sd_cmd = CMD_INHIBIT; // current command sent to sd ram

  assign sd_clk = !clk100_mhz; // chip clock shifted 180 deg.

  // drive control signals according to current command
  assign sd_cs  = sd_cmd[3];
  assign sd_ras = sd_cmd[2];
  assign sd_cas = sd_cmd[1];
  assign sd_we  = sd_cmd[0];

  // sdram tri-state databus interaction
  reg  sd_data_wr = 1'b0;
  wire sd_data_rd = (t==STATE_READ) & rw & memact;
  assign sd_data  = sd_data_wr ? din : 16'hzzzz;
  always @(posedge clk100_mhz) if(sd_data_rd) dout <= sd_data;
  
  // controller<->CPU cycle management
  wire block  = !asn & udsn & ldsn; // block start of new refresh cycle if about to write
  wire memcyc = !(udsn & ldsn) & !asn; // start memory cycle
  reg  memact = 0; // memory cycle active

  always @(posedge clk100_mhz) begin
    sd_cmd <= CMD_INHIBIT;  // default: idle
    sd_cke <= 1'b1;
    
    // move to next state, but stay at start early in write cycle,
    // or at end when mem cycle not complete yet. When in a refresh
    // cycle, stop at state 6.
    t <= t + 1;
    if(rst) t <= STATE_FIRST;
    if((t==STATE_FIRST) & block) t <= t;
    if(t==STATE_LAST) t <= memcyc ? t : STATE_FIRST;
    if(!memact & (t==STATE_READ)) t <= STATE_FIRST;

    if(reset != 0) begin // reset operation
      case(reset)
      22: sd_ba   <= 2'b00;
      21: sd_addr[10] <= 1'b1; // prep for precharge all banks
      20: sd_cmd  <= CMD_PRECHARGE;
      11: sd_addr <= MODE;
      10: sd_cmd  <= CMD_LOAD_MODE;
      endcase
    end
    
    else begin // normal operation after reset
      if(t == STATE_FIRST) begin
        sd_addr <= { 1'b0, addr[19:8] };
        sd_ba   <= addr[21:20];
        if (memcyc) begin
          // start memory cycle, RAS phase
          memact  <= 1'b1;
          sd_cmd  <= CMD_ACTIVE;
        end
        else if(!block) begin
          // start refresh cycle if not blocked
          memact <= 1'b0;
          sd_cmd <= CMD_AUTO_REFRESH;
        end
      end

      // ---------  do CAS phase, perform read/write ----------------------
      if(memact) begin

        if(t == STATE_CMD_CAS-1) begin
          // set up output data early
          sd_data_wr <= !rw;
          sd_dqm <= rw ? 2'b00 : { udsn, ldsn };
          sd_addr <= { 4'b0010, addr[22], addr[7:0] };
        end
        if(t == STATE_CMD_CAS)   sd_cmd <= rw ? CMD_READ : CMD_WRITE;
        if(t == STATE_CMD_CAS+1) sd_data_wr <= 1'b0; // revert sd_data to hi-z
        if(t == STATE_CMD_CAS+2) sd_cke <= !rw; // keep read data for 2 clocks
        
      end
      
    end
  end

endmodule
