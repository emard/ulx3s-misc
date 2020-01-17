//
// Simplistic SDRAM controller for 4x4Mx16 chips (e.g. micron MT48LC16M16A2)
//  - makes one sdram access for each system access
//  - can keep all 4 banks open
//  - distributed refresh
//
// This source code is public domain
//
module sdram_pnru (
    // system interface
    input  wire        sys_clk,             // CLK 125 Mhz
    input  wire        sys_rd,              // read word
    input  wire        sys_wr,              // write word
    output reg         sys_rdy = 1'b0,      // mem ready
    input  wire        sys_ack,             // mem cycle end
    input  wire [23:0] sys_ab,              // address
    input  wire [15:0] sys_di,              // data in
    output reg  [15:0] sys_do,              // data out

    // sdram interface
    output wire  [3:0] sdr_n_CS_WE_RAS_CAS, // SDRAM nCS, nWE, nRAS, nCAS
    output wire  [1:0] sdr_ba,              // SDRAM bank address
    output reg  [12:0] sdr_ab,              // SDRAM address
    inout  wire [15:0] sdr_db,              // SDRAM data
    output reg   [1:0] sdr_dqm = 2'b11      // SDRAM DQM  
  );

  // SDRAM timing parameters
  localparam tRP = 3, tMRD = 2, tRCD = 3, tRC = 9, CL = 3;
  localparam INITLEN = 12500; // 125 * 100us;
  localparam RFTIME  =   975; // 125 * 7.8us;

  // cross clock domain
  reg [15:0] di;
  reg [23:0] ab;
  reg rd, wr, ack;
  always @(posedge sys_clk) begin
    di <= sys_di;
    ab <= sys_ab;
    rd <= sys_rd;
    wr <= sys_wr;
    ack <= sys_ack;
  end
 // wire di = sys_di;
  
  // dataflow assignments
  assign sdr_n_CS_WE_RAS_CAS = sdr_cmd;
  assign sdr_ba = (state==CONFIG) ? 2'b00 : ab[10:9];
  assign sdr_db = (state==RWRDY && wr) ? di : 16'hzzzz;
  
  // controller states & FSM
  localparam IDLE = 0, RFRSH1 = 1, RFRSH2 = 2, CONFIG = 3, RDWR = 4, RWRDY = 5, ACKWT = 6, WAIT = 7;

  reg  [3:0] sdr_cmd;               // command issued to sdram
  reg  [2:0] state   = IDLE;        // FSM state
  reg  [2:0] next;                  // new state after waiting
  reg [15:0] ctr     = 0;           // refresh/init counter
  reg  [6:0] dly;                   // FSM delay counter
  reg  [3:0] open;                  // open bank flags
  reg [12:0] opnrow[0:3];           // open row numbers
  
  // convenience signals
  wire        init = sdr_dqm[0];     // note: DQM==2'b11 during init, 2b'00 thereafter
  wire  [8:0] col  = ab[8:0];
  wire [12:0] row  = ab[23:11];
  wire  [2:0] ba   = ab[10:9];
  
  // SDRAM command codes
  localparam NOP  = 4'b1000, PRECHRG = 4'b0001, AUTORFRSH = 4'b0100, MODESET = 4'b0000,
             READ = 4'b0110, WRITE   = 4'b0010, ACTIVATE  = 4'b0101;

  // SDRAM mode register: single word reads & writes, CL=3, sequential access
  localparam MODE = 13'b000_1_00_011_0_000;
  
  always @(posedge sys_clk)
  begin
    ctr <= ctr + 1;
    dly <= dly - 1;
    
    // default FSM operations
    sdr_cmd <= NOP;
    state   <= WAIT;

    case (state)
    
      IDLE:   if (init) state <= (ctr==INITLEN) ? RFRSH1 : IDLE; // remain in idle for >100us at init
              else begin
                sys_rdy <= 1'b0;
                if (ctr>=RFTIME) state <= RFRSH1;         // as needed, refresh a row
                else if (rd|wr)  state <= RDWR;           // else respond to rd or wr request
                else begin
                  sys_rdy <= 1'b1;
                  state <= IDLE;                                 // else do nothing
                end
              end

      RFRSH1: begin // prior to refresh, close all banks
                sdr_cmd    <= PRECHRG;
                sdr_ab[10] <= 1'b1;    // do all banks
                open       <= 4'b000;
                dly <= tRP-2; next <= (init) ? CONFIG : RFRSH2; // insert config step during init
              end

      RFRSH2: begin // refresh one row, then return to IDLE
                sdr_cmd <= AUTORFRSH;
                sdr_dqm <= 2'b00;     // end init
                ctr     <= 0;         // reset timeout
                dly <= tRC-2; next <= (init) ? RFRSH2 : IDLE;  // repeat AUTORFRSH during init
              end

      CONFIG: begin // load the mode register
                sdr_cmd <= MODESET;
                sdr_ab  <= MODE;
                dly <= tMRD-2; next <= RFRSH2;
              end

      RDWR:   begin // issue read or write command
                if (!open[ba]) begin // if not open, open row first & restart
                  sdr_cmd <= ACTIVATE;
                  sdr_ab  <= row;
                  open[ba]   <= 1'b1; // mark as open
                  opnrow[ba] <= row;
                  dly <= tRCD-2; next <= RDWR;
                  end
                else if (opnrow[ba]!=row) begin // if wrong row, close it & restart
                  sdr_cmd      <= PRECHRG;
                  sdr_ab[10]   <= 1'b0;  // for one bank only
                  open[ba] <= 1'b0;  // mark as closed
                  dly <= tRP-2; next <= RDWR;
                  end
                else begin // all good, issue R/W command
                  sdr_cmd <= (rd) ? READ : WRITE;
                  sdr_ab  <= {4'b0000, col};
                  dly <= CL-1; next <= RWRDY;
                  if (wr) state <= RWRDY; // no delay needed for writes
                  end
              end
      
      RWRDY:  begin // latch read result, or write data
                sys_rdy <= 1'b1;
                if (rd) sys_do  <= sdr_db;
                state <= ACKWT;
              end
              
      ACKWT:  // wait for system to end current r/w cycle
              state <= (ack) ? IDLE : ACKWT;
      
      WAIT:   // wait 'dly' clocks before progressing to state 'next'   
              state <= (|dly) ? WAIT : next;
              
    endcase
  end

endmodule
