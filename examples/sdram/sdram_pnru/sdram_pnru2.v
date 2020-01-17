
module sdram_pnru2 (
    // system interface
    input  wire        sys_clk, // CLK 125 Mhz
    input  wire        sys_rd,  // read word
    input  wire        sys_wr,  // write word
    input  wire        sys_cs,  // chip select
    input  wire [23:0] sys_ab,  // address
    input  wire [15:0] sys_di,  // data in
    output reg  [15:0] sys_do,  // data out
    output wire        sys_rdy, // mem ready

    // sdram interface
    output reg         sdr_clk, // SDRAM clk
    output reg   [3:0] sdr_cmd, // SDRAM {nCS, nWE, nRAS, nCAS}
    output reg   [1:0] sdr_ba,  // SDRAM bank address
    output reg  [12:0] sdr_ab,  // SDRAM address
    inout  wire [15:0] sdr_db,  // SDRAM data
    output reg   [1:0] sdr_dqm  // SDRAM DQM  
  );

  // Sync inputs with our clock
  reg [15:0] di;
  reg [23:0] ab;
  reg rd, wr;
  always @(posedge sys_clk)
      {ab, di, rd, wr} <= {sys_ab, sys_di, sys_rd&sys_cs, sys_wr&sys_cs};

  // SDRAM timing parameters
  localparam tRP = 3, tMRD = 2, tRCD = 3, tRC = 9, CL = 3;
  localparam INITLEN = 12500; // 125 * 100us;
  localparam RFTIME  =   975; // 125 * 7.8us;

  // SDRAM command codes {nCS, nWE, nRAS, nCAS}
  localparam NOP  = 4'b1000, PRECHRG = 4'b0001, AUTORFRSH = 4'b0100, LOAD = 4'b0000,
             READ = 4'b0110, WRITE   = 4'b0010, ACTIVATE  = 4'b0101;
  
  // SDRAM mode register: single byte reads & writes, CL=3, sequential access
  localparam MODE = 13'b000_1_00_011_0_000;

  // Controller states & FSM
  //
  localparam IDLE = 0, RF1 = 1, RF2 = 2, CNF = 3, RAS = 4, CAS = 5, ACKWT = 6, WAIT = 7;
  
  reg  [2:0] state   = IDLE;        // FSM state
  reg  [2:0] next;                  // new state after waiting
  reg [15:0] ctr     = 0;           // refresh/init counter
  reg  [6:0] dly;                   // FSM delay counter
  reg  [1:0] dqm_d   = 2'b11;       // SQM diver (11 during init, 00 thereafter)
  
  wire ack = !(rd|wr);
  wire init = sdr_dqm[0];
  
  always @(posedge sys_clk)
  begin

    state <= WAIT;
    if (state==RF2) dqm_d <= 2'b00;

    ctr   <= (state==RF2) ? 0 : ctr + 1;
    dly   <= dly - 1;
    
    case (state)
    
      IDLE:   if (init) state <= (ctr==INITLEN) ? RF1 : IDLE; // remain in idle for >100us at init
              else begin
                if (ctr>=RFTIME) state <= RF1;   // as needed, refresh a row
                else if (rd|wr)  state <= RAS;   // else respond to rd or wr request
                else             state <= IDLE;  // else do nothing
              end

      RF1:    begin dly <= tRP-2;  next <= (init) ? CNF : RF2;  end  // close all banks, insert config during init
      CNF:    begin dly <= tMRD-2; next <= RF2;                 end  // load the mode register
      RF2:    begin dly <= tRC-2;  next <= (init) ? RF2 : IDLE; end  // refresh one row (two during init), then return to IDLE

      RAS:    begin dly <= tRCD-2; next <= CAS;    end               // issue activate
      CAS:    begin dly <= CL-1;   next <= ACKWT;  end               // issue R/W command with auto-precharge
      ACKWT:  begin next <= IDLE; state <= (ack) ? IDLE : ACKWT; end // wait for system to end current r/w cycle
      
      WAIT:   state <= (dly!=0) ? WAIT : next;   // wait 'dly' clocks before going to state 'next' 
              
    endcase
  end

  assign sys_rdy = (state==ACKWT);

  // Prepare SDRAM output signals based on FSM state
  //
  reg  [3:0] cmd_d; // command issued to sdram
  reg  [1:0] ba_d;  // bank address
  reg [12:0] ab_d;  // ras, cas address or configuration
  always @(*)
  begin
    cmd_d = NOP;
    ab_d  = { 4'b0010, ab[8:0] };
    ba_d  = ab[10:9];
    case (state)
      RF1: begin cmd_d = PRECHRG;            /* note: ab_d[10] = 1 */     end
      RF2: begin cmd_d = AUTORFRSH;          /* note: ab_d[10] = 1 */     end
      CNF: begin cmd_d = LOAD;               ab_d = MODE; ba_d = 2'b00;   end
      RAS: begin cmd_d = ACTIVATE;           ab_d = ab[23:11];            end
      CAS: begin cmd_d = rd ? READ : WRITE;  ab_d = { 4'b0010, ab[8:0] }; end
    endcase
  end

  // Place external SDRAM signals directly in IO pads for consistent timing
  //
  wire in  = (next==ACKWT) && (dly==0) && rd;
  wire out = (next==ACKWT) && (dly==CL-1) && wr;
  wire [15:0] xdb;

//`ifdef __ICARUS__
  always @(sys_clk) #2 sdr_clk <= sys_clk;  // delay sdr chip clock by 2ns

  always @(posedge sys_clk) sdr_cmd <= cmd_d;
  always @(posedge sys_clk) sdr_ab  <= ab_d;
  always @(posedge sys_clk) sdr_ba  <= ba_d;
  always @(posedge sys_clk) sdr_dqm <= dqm_d;
  
  assign sdr_db = (out) ? sys_di : 16'hzzzz;
  always @(posedge sys_clk) if (in) sys_do  <= sdr_db;
//`else
/*
  //DELAYG #(.DEL_VALUE(60)) clk_dly(clk_sdr, sdram_clk);

  OFS1P3BX cmd_FF[ 3:0] (.D(cmd_d), .Q(sdr_cmd), .SCLK(sys_clk);
  OFS1P3BX  ab_FF[15:0] (.D(ab_d),  .Q(sdr_ab),  .SCLK(sys_clk);
  OFS1P3BX  ba_FF[ 1:0] (.D(ab_d),  .Q(sdr_ba) , .SCLK(sys_clk);
  OFS1P3BX dqm_FF[ 1:0] (.D(dqm_d), .Q(sdr_dqm), .SCLK(sys_clk);
  
  BB       db_buf[15:0] (.I(sys_dbi), .O(dbx), .B(sdr_db), .T(out));
  IFS1P3BX dbi_FF[15:0] (.D(dbx), .Q(sys_dbo), .SCLK(sys_clk), .PE(in));
*/
//`endif

endmodule
