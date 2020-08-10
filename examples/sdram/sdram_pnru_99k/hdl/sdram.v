//
// sdram.v
//
// This source code is public domain
//
// TMS99000 SDRAM controller. Operate at >4x CPU clock speed (i.e. 16x CPU clkout)
//   PC133 (grade 7) chips work up to 143Mhz
//   PC166 (grade 6) chips work up to 166MHz
//

module SDRAM (
  input             clk_in,     // controller clock
  
  // interface to the chip
  inout      [15:0] sd_data,    // 16 bit databus
  output reg [12:0] sd_addr,    // 13 bit multiplexed address bus
  output reg [1:0]  sd_dqm,     // two byte masks
  output reg [1:0]  sd_ba,      // two banks
  output            sd_cs,      // chip select
  output            sd_we,      // write enable
  output            sd_ras,     // row address select
  output            sd_cas,     // columns address select
  output            sd_cke,     // clock enable
  output            sd_clk,     // chip clock (inverted from input clk)

  // TMS99000 interface
  input      [15:0] din,        // data input from cpu
  output reg [15:0] dout,       // data output to cpu
  input      [23:0] addr,       // 24 bit word address
  input             csn,        // chip select (incl. nmemen)
  input             as,         // as, start of new CPU machine cycle
  input             nwr,        // cpu write cycle
  input             rst         // cpu reset
);

  localparam RASCAS_DELAY   = 3'd3;   // tRCD=20ns -> 3 cycles @ >100MHz
  localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
  localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
  localparam CAS_LATENCY    = 3'd3;   // 3 needed @ >100Mhz
  localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
  localparam NO_WRITE_BURST = 1'b1;   // 0=write burst enabled, 1=only single access write

  localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

  // ---------------------------------------------------------------------
  // ------------------------ cycle state machine ------------------------
  // ---------------------------------------------------------------------

  // The state machine runs at 125Mhz, synchronous to the CPU
  // Each CPU machine cycle is a r/w cycle and a refresh cycle

  localparam STATE_FIRST     = 0;  // idle state, prep command
  localparam STATE_CMD_CAS   = STATE_FIRST  + RASCAS_DELAY; // prep CAS cycle
  localparam STATE_READ      = STATE_CMD_CAS + CAS_LATENCY + 1;
  localparam STATE_CMD_RFSH  = STATE_READ + 1;

  reg [3:0] t;

  // ---------------------------------------------------------------------
  // --------------------------- startup/reset ---------------------------
  // ---------------------------------------------------------------------

  // make sure rst lasts long enough (recommended 100us)
  reg [4:0] reset;
  always @(posedge clk_in) begin
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

  assign sd_clk = !clk_in; // chip clock shifted 180 deg.
  assign sd_cke = 1'b1;

  // drive control signals according to current command
  assign sd_cs  = sd_cmd[3];
  assign sd_ras = sd_cmd[2];
  assign sd_cas = sd_cmd[1];
  assign sd_we  = sd_cmd[0];

  // sdram tri-state databus interaction
  reg  sd_data_wr = 1'b0;
  wire sd_data_rd = (t==STATE_READ) & !nwr & memact;
  assign sd_data  = sd_data_wr ? din : 16'hzzzz;
`ifdef __ICARUS__
  always @(posedge sd_clk) if(sd_data_rd) dout <= sd_data;
`else
  wire rd_clk;
  DLY2NS dly(.in(sd_clk), .out(rd_clk));
  IFS1P3BX dbi_FF[15:0] (.SCLK(rd_clk), .SP(sd_data_rd), .Q(dout), .D(sd_data), .PD(1'b0));
`endif
  
  // controller state machine
  reg  memact = 0; // memory cycle active

  always @(posedge clk_in) begin
    sd_cmd <= CMD_INHIBIT;  // default: idle
    
    // move to next state
    t <= t + 1;
    if(rst | as) t <= STATE_FIRST;

    if(reset != 0) begin // reset operation
      case(reset)
      22: sd_ba   <= 2'b00;
      21: sd_addr[10] <= 1'b1; // prep for precharge all banks
      20: sd_cmd  <= CMD_PRECHARGE;
      11: sd_addr <= MODE;
      10: sd_cmd  <= CMD_LOAD_MODE;
      endcase
    end
    
    else begin // normal operation
      case(t)
      // RAS phase
      STATE_FIRST: begin
        sd_addr <= { 1'b0, addr[19:8] };
        sd_ba   <= addr[21:20];
        if (!as) sd_cmd  <= CMD_ACTIVE;
        end
      // CAS phase
      STATE_CMD_CAS-1: begin // set up output data early
          sd_data_wr <= !nwr;
          sd_dqm  <= 2'b00;
          sd_addr <= { 4'b0010, addr[22], addr[7:0] };
          end
      STATE_CMD_CAS:   sd_cmd <= nwr ? CMD_READ : CMD_WRITE;
      STATE_CMD_CAS+1: sd_data_wr <= 1'b0; // revert sd_data to hi-z
      // refresh phase
      STATE_CMD_RFSH:  sd_cmd <= CMD_AUTO_REFRESH;
      endcase
    end
  end

endmodule

// poor solution to generate ~2ns delay
//
`ifndef __ICARUS__

module DLY2NS (
  input  wire in,
  output wire out
);

  (* keep *) wire x1 = !in;
  (* keep *) wire x2 = !x1;
  (* keep *) wire x3 = !x2;
  (* keep *) wire x4 = !x3;
  assign out = x4;
  
endmodule

`endif
