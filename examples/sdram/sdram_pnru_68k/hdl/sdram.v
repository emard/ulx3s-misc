// sdram.v
//
// derived from sdram controller for Mist board, which is
// copyright (c) 2013 Till Harbaum <till@harbaum.org> + GPL v3
//
// modifications public domain 

module sdram
(
  input             clk100_mhz, // sdram is accessed at 100MHz

  // interface to the MT48LC16M16 chip
  inout      [15:0] sd_data,    // 16 bit databus
  output reg [12:0] sd_addr,    // 13 bit multiplexed address bus
  output reg  [1:0] sd_dqm,     // two byte masks
  output reg  [1:0] sd_ba,      // two banks
  output            sd_cs,      // a single chip select
  output            sd_we,      // write enable
  output            sd_ras,     // row address select
  output            sd_cas,     // columns address select

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

  localparam RASCAS_DELAY   = 3'd3;   // tRCD=20ns -> 2 cycles@96MHz
  localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
  localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
  localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
  localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
  localparam NO_WRITE_BURST = 1'b1;   // 0=write burst enabled, 1=only single access write

  localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

  // ---------------------------------------------------------------------
  // ------------------------ cycle state machine ------------------------
  // ---------------------------------------------------------------------

  // The state machine runs at 100Mhz, asynchronous from the CPU

  localparam STATE_FIRST     = 4'd0;   // first state in cycle
  localparam STATE_CMD_CONT  = STATE_FIRST  + RASCAS_DELAY; // command can be continued
  localparam STATE_READ      = STATE_CMD_CONT + CAS_LATENCY + 4'd1;
  localparam STATE_LAST      = 4'd8;  // last state in cycle

  reg [3:0] t;

  // ---------------------------------------------------------------------
  // --------------------------- startup/reset ---------------------------
  // ---------------------------------------------------------------------

  // make sure rst lasts long enough (recommended 100us)
  reg [4:0] reset;
  always @(posedge clk100_mhz) begin
    reset <= (|reset) ? reset - 5'd1 : 0;
    if(rst)	reset <= 5'h1f;
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

  reg  [3:0] sd_cmd;       // current command sent to sd ram

  // drive control signals according to current command
  assign sd_cs  = sd_cmd[3];
  assign sd_ras = sd_cmd[2];
  assign sd_cas = sd_cmd[1];
  assign sd_we  = sd_cmd[0];

  reg [23:0] addr_latch;   // saved address
  reg sd_data_wr;          // switch db to write

  assign sd_data = sd_data_wr ? din : 16'hzzzz;

  reg        rd = 0;
  
  // block start of new refresh cycle if about to write
  wire block  = !asn & udsn & ldsn;
  wire memcyc = !(udsn & ldsn) & !asn;
  reg  memact = 0;

  always @(posedge clk100_mhz) begin
    // permanently latch ram data to reduce delays
    sd_cmd     <= CMD_INHIBIT;  // default: idle
    sd_data_wr <= 0;
    rd <= 0;
    
    // move to next state, but stay at start early in write cycle,
    // or at end when mem cycle not complete yet. When in a refresh
    // cycle, stop at state 6.
    t <= t + 1;
    if(rst) t <= STATE_FIRST;
    if((t==STATE_FIRST) & block) t <= t;
    if(t==STATE_LAST) t <= memcyc ? t : STATE_FIRST;
    if(!memact & (t==STATE_READ)) t <= STATE_FIRST;

    if(reset != 0) begin // reset operation
        if(reset == 30) begin
          sd_cmd <= CMD_PRECHARGE;
          sd_addr[10] <= 1'b1;      // precharge all banks
        end
        if(reset == 20) begin
          sd_cmd <= CMD_LOAD_MODE;
          sd_addr <= MODE;
        end
        if(reset == 10) begin
          sd_cmd <= CMD_AUTO_REFRESH;
        end
    end
    
    else begin // normal operation after reset
      if(t == STATE_FIRST) begin
        if (memcyc) begin
          // start memory cycle, RAS phase
          memact <= 1'b1;
          addr_latch <= addr;
          sd_cmd <= CMD_ACTIVE;
          sd_addr <= { 1'b0, addr[19:8] };
          sd_ba <= addr[21:20];
        end
        else if(!block) begin
          // start refresh cycle if not blocked
          memact <= 1'b0;
          sd_cmd <= CMD_AUTO_REFRESH;
        end
      end

      // -------------------  perform read/write ----------------------
      if(memact) begin

        // CAS phase 
        if(t == STATE_CMD_CONT) begin
          sd_cmd <= rw ? CMD_READ : CMD_WRITE;
          sd_data_wr <= !rw;
          // always return both bytes in a read. The cpu may not
          // need it, but it does not harm
          sd_dqm <= rw ? 2'b00 : { udsn, ldsn };
          sd_addr <= { 4'b0010, addr_latch[22], addr_latch[7:0] };  // auto precharge
        end

        // read phase
        if(rw && (t == STATE_READ)) begin
          rd <= 1;
          dout <= sd_data;
        end
      end      
    end
  end

endmodule
