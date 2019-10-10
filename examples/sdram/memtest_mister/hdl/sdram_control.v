/*
  read sequence

clk   ``\____/````\____/` ..... _/````\____/````\____/` ..... _/````\____/````\____/`
             |         |         |         |         |         |         |
start XXXX```````````\__ ....... ____________________________________________________
             |         |         |         |         |         |         |
rnw   XXXXXX```XXXXXXXXX ....... XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
             |         | some    |         |         |         |         |
ready XXXXXXX\__________ clocks __/``````````````````  ....... ```````````\__________
                         before                                |         |
rdat  ------------------ ready  -< cell 0  | cell 1  | ....... |last cell>-----------
             |         |         |         |         |         |         |
done  XXXXXXX\__________ ....... _____________________ ....... ___________/``````````
                                                                            ^all operations stopped until next start strobe



  write sequence

clk   ``\____/````\____/` ..... _/````\____/````\____/````\____/````\____/````\____/````\____/````\____/
             |         | some    |         | some    |         |         |         |         |         |
start XXXX```````````\__ ....... _____________ .... ______________ .... ________________________________
             |         | clocks  |         | clocks  |         |         |         |         |         |
rnw   XXXXXX___XXXXXXXXX ....... XXXXXXXXXXXXX .... XXXXXXXXXXXXXX .... XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
             |         | before  |         | before  |         |         |         |         |         |
ready XXXXXXX\__________ ....... _/`````````\_ .... __/`````````\_ .... __/`````````\___________________
             |         | first   |         | next    |         |         |         |         |         |
wdat  XXXXXXXXXXXXXXXXXXXXXXXXXXXX< cell 0  >X .... XX< cell 1  >X .... XX<last cell>XXXXXXXXXXXXXXXXXXX
             |         | ready   |         | ready   |         |         |         |         |         |
done  XXXXXXXX\_________ ....... _____________ .... ______________ .... ____________/```````````````````
             |         | strobe  |         | strobe  |         |         |         |         |         |

*/


module sdram_control
#(
// different bus sizes
parameter DRAM_DATA_SIZE = 16,

parameter DRAM_COL_SIZE = 9,
parameter DRAM_ROW_SIZE = 13,
parameter DRAM_BNK_SIZE = 2,
parameter DRAM_ROWBNK = DRAM_ROW_SIZE + DRAM_BNK_SIZE,


// commands for SDRAM, RAS-CAS-WE bits
parameter cmdNOP  = 3'b111, // no op
parameter cmdMRS  = 3'b000, // mode register set
parameter cmdACT  = 3'b011, // activate
parameter cmdREAD = 3'b101, // either with autoprecharge or not, depends on A10
parameter cmdWRIT = 3'b100, // same as for read
parameter cmdPRE  = 3'b010, // either single bank or all banks, depends on A10
parameter cmdBST  = 3'b110, // burst stop
parameter cmdREF  = 3'b001, // refresh

parameter mrsMODE = 14'b00000000110111, // cas latency=2/3, sequential fullpage burst

// some timing constants
parameter CTR200US_SIZE = 15 // multifunctional counter with a maximum delay for startup 200us-minimum pause
)
(
/*
  clk,
  rst_n,

  start,

  done,

  rnw,

  ready,


  wdat, // input, data to be written to memory
  rdat, // output, data last read from memory

  sdram_state,

  DRAM_DQ,
  DRAM_ADDR,

  DRAM_LDQM,DRAM_UDQM,
  DRAM_WE_N,
  DRAM_CAS_N,
  DRAM_RAS_N,
  DRAM_CS_N,
  DRAM_BA_0,
  DRAM_BA_1
*/
input clk,
input rst_n, // total reset
input start, // start sequence
output reg done, // =1 when operation is done,
					 // also done=0 while reset SDRAM initialisation is in progress
input rnw, // 1 - read, 0 - write sequence (latched when start=1)
output reg ready, // strobe. when writing, one mean that data from wdat written to the memory
					  // when reading, one mean that data read from memory is on rdat output

output DRAM_LDQM,DRAM_UDQM,
output DRAM_WE_N,
output DRAM_CAS_N,
output DRAM_RAS_N,
output DRAM_CS_N,
output DRAM_BA_0,
output DRAM_BA_1,



input      [DRAM_DATA_SIZE-1:0] wdat,

output reg [DRAM_DATA_SIZE-1:0] rdat,


inout wire  [DRAM_DATA_SIZE-1:0] DRAM_DQ,
output wire [DRAM_ROW_SIZE-1:0] DRAM_ADDR,

output [5:0] sdram_state


);



/*
input clk;
input rst_n; // total reset
input start; // start sequence
output reg done; // =1 when operation is done,
					 // also done=0 while reset SDRAM initialisation is in progress
input rnw; // 1 - read, 0 - write sequence (latched when start=1)
output reg ready; // strobe. when writing, one mean that data from wdat written to the memory
					  // when reading, one mean that data read from memory is on rdat output

output DRAM_LDQM,DRAM_UDQM;
output DRAM_WE_N;
output DRAM_CAS_N;
output DRAM_RAS_N;
output DRAM_CS_N;
output DRAM_BA_0;
output DRAM_BA_1;



input      [DRAM_DATA_SIZE-1:0] wdat;

output reg [DRAM_DATA_SIZE-1:0] rdat;


inout reg   [DRAM_DATA_SIZE-1:0] DRAM_DQ;
output wire [DRAM_ROW_SIZE-1:0] DRAM_ADDR;
*/

reg [DRAM_ROW_SIZE-1:0] da; // SDRAM address
reg [2:0] dcmd; // SDRAM cmd reg, mapped to RAS-CAS-WE pins
reg       dcsn; // SDRAM CS_n signal
reg [1:0] dba; // SDRAM bank address
reg       dqm; // mapped to BOTH LDQM and UDQM since only word access

assign DRAM_ADDR                         = da;
assign {DRAM_RAS_N,DRAM_CAS_N,DRAM_WE_N} = dcmd;
assign DRAM_CS_N                         = dcsn;
assign {DRAM_BA_1,DRAM_BA_0}             = dba;
assign DRAM_LDQM                         = dqm;
assign DRAM_UDQM                         = dqm;


assign sdram_state = state;


reg [5:0] state;


reg [CTR200US_SIZE:0] ctr; // 200us counter
reg ctr_init;


reg [DRAM_ROWBNK:0] actr; // row-bank address counter
reg actr_rst;
reg actr_inc;


reg busin; // =1 - DRAM_DQ inputs, =0 - outputs


//=============================================================================
localparam RESET        = 6'd00;
localparam RST2         = 6'd01;

localparam W200US1      = 6'd02;
localparam W200US2      = 6'd03;

localparam IPREA1       = 6'd04;
localparam IPREA2       = 6'd05;

localparam IREF1        = 6'd06;
localparam IREF2        = 6'd07;
localparam IREF3        = 6'd08;
localparam IREF4        = 6'd09;
localparam IREF5        = 6'd10;
localparam IREF6        = 6'd11;
localparam IREF7        = 6'd12;

localparam IMRS         = 6'd13;

localparam IDLE         = 6'd14;

localparam RD_BEGIN1    = 6'd15;
localparam RD_BEGIN2    = 6'd16;
localparam RD_CHKEND    = 6'd17;
localparam RD_COL1      = 6'd18;
localparam RD_COL2      = 6'd19;
localparam RD_COL3      = 6'd20;
localparam RD_COL4      = 6'd21;
localparam RD_COL4_1    = 6'd22;
localparam RD_COL5      = 6'd23;
localparam RD_COL6      = 6'd24;
localparam RD_WAIT      = 6'd25;
localparam RD_PRE       = 6'd26;
localparam RD_END1      = 6'd27;
localparam RD_END2      = 6'd28;

localparam WR_BEGIN1    = 6'd29;
localparam WR_BEGIN2    = 6'd30;
localparam WR_CHKEND    = 6'd31;
localparam WR_COL1      = 6'd32;
localparam WR_COL2      = 6'd33;
localparam WR_COL3      = 6'd34;
localparam WR_WAIT1     = 6'd35;
localparam WR_WAIT2     = 6'd36;
localparam WR_BST       = 6'd37;
localparam WR_PRE       = 6'd38;
localparam WR_END1      = 6'd39;



///////////////////////////////////////////////////////////////////////////////
///////////////////////////////// main FSM ////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

// next state selection
always @(posedge clk) begin
	if (!rst_n) state <= RESET;
	else
	case( state )
		///////////////////////////////////////////////////////////////////////////////
		RESET:     state <= RST2;
		RST2:      state <= W200US1;
		W200US1:   state <= W200US2;
		W200US2:
			if( ctr[CTR200US_SIZE] )
				state <= IPREA1;
			else
				state <= W200US2;

		IPREA1:    state <= IPREA2;
		IPREA2:    state <= IREF1;

		IREF1:     state <= IREF2;
		IREF2:     state <= IREF3;
		IREF3:     state <= IREF4;
		IREF4:     state <= IREF5;
		IREF5:     state <= IREF6;
		IREF6:     state <= IREF7;
		IREF7:
			if( ctr[7] ) state <= IMRS;
				else state <= IREF1;

		IMRS:   state <= IDLE;

		IDLE:
			begin
				if( start ) begin
					if( rnw ) state <= RD_BEGIN1;
						else state <= WR_BEGIN1;
				end
					else state <= IDLE;
			end

		RD_BEGIN1: state <= RD_BEGIN2;
		RD_BEGIN2: state <= RD_CHKEND;
		RD_CHKEND:
			begin
				if( actr[DRAM_ROWBNK] )
					state <= IDLE;
				else
					state <= RD_COL1;
			end

		RD_COL1:   state <= RD_COL2;
		RD_COL2:   state <= RD_COL3;
		RD_COL3:   state <= RD_COL4;
		RD_COL4:   state <= mrsMODE[4] ? RD_COL4_1 : RD_COL5;
		RD_COL4_1: state <= RD_COL5;
		RD_COL5:   state <= RD_COL6;
		RD_COL6:   state <= RD_WAIT;

		RD_WAIT:
			begin
				if( ctr[DRAM_COL_SIZE] )
					state <= RD_PRE;
				else
					state <= RD_WAIT;
			end

		RD_PRE:    state <= RD_END1;
		RD_END1:   state <= RD_END2;
		RD_END2:   state <= RD_CHKEND;


		WR_BEGIN1: state <= WR_BEGIN2;
		WR_BEGIN2: state <= WR_CHKEND;

		WR_CHKEND:
			begin
				if( actr[DRAM_ROWBNK] )
					state <= IDLE;
				else
					state <= WR_COL1;
			end

		WR_COL1:   state <= WR_COL2;
		WR_COL2:   state <= WR_COL3;
		WR_COL3:   state <= WR_WAIT1;

		WR_WAIT1:
			begin
				if( ctr[DRAM_COL_SIZE] )
					state <= WR_WAIT2;
				else
					state <= WR_WAIT1;
			end

		WR_WAIT2:  state <= WR_BST;
		WR_BST:    state <= WR_PRE;
		WR_PRE:    state <= WR_END1;
		WR_END1:   state <= WR_CHKEND;

	endcase;
end


//outputs control
// special case for async-resetting signals
always @(posedge clk) begin
	if( !rst_n ) begin
		dcsn  <= 1'b1;
		done  <= 1'b0;
		busin <= 1'b1;
	end
	else // posedge clk
	begin
		case( state )

			///////////////////////////////////////////////////////////////////////////////
			RST2: begin
				dcsn <= 1'b0;
				dcmd <= cmdNOP;
				dqm <= 1'b1;
				ctr_init <= 1'b1; // begin counting
				ready <= 1'b0;
			end

			W200US1: // here ctr_init actually pulses
				ctr_init <= 1'b0;

			//W200US2: // here ctr_init again 0, counting in progress, we wait for MSB to become 1


			IPREA1: begin // here we begin precharge all command
				dcmd <= cmdPRE; da[10] <= 1'b1; // precharge ALL command
			end

			IPREA2: begin // waiting for Trp=20ns, which is 2 cycles at 100 MHz
				dcmd <= cmdNOP;
				ctr_init <= 1'b1; // re-init counter for counting time of init-time auto refresh cycles
			end

			IREF1: begin
				ctr_init <= 1'b0;
				dcmd <= cmdREF; // begin auto-refresh cycle
			end

			IREF2: begin
				dcmd <= cmdNOP;
			end

			IMRS: begin
				dcmd <= cmdMRS;
				{dba,da} <= mrsMODE;
			end

			IDLE: begin
				dcmd  <= cmdNOP;
				dqm   <= 1'b0; // able to go through all operations with no masking ever
				done  <= 1'b1;
				busin <= 1'b1;
				ready <= 1'b0;
			end

			RD_BEGIN1: begin
				busin <= 1'b1;
				done <= 1'b0;
				actr_rst <= 1'b1; // reset counter
			end

			RD_BEGIN2: begin
				actr_rst <= 1'b0; // end resetting counter
			end

			RD_CHKEND: begin
				ctr_init <= ~mrsMODE[4];
				ready <= 1'b0;
			end

			RD_COL1: begin
				dcmd <= cmdACT;
				da   <= actr[DRAM_ROWBNK-1:DRAM_BNK_SIZE];
				dba  <= actr[DRAM_BNK_SIZE-1:0];

				ctr_init <= mrsMODE[4];
			end

			RD_COL2: begin
				dcmd <= cmdNOP;
				ctr_init <= 0;
			end

			RD_COL3: begin
				dcmd <= cmdREAD;
				da   <= 0;
				dba  <= actr[DRAM_BNK_SIZE-1:0];
			end

			RD_COL4: begin
				dcmd <= cmdNOP;
			end

			RD_COL6: begin
				ready <= 1'b1;
			end

			RD_PRE: begin
				dcmd <= cmdPRE;
				da   <= 0;
				dba  <= actr[DRAM_BNK_SIZE-1:0];
			end

			RD_END1: begin
				dcmd <= cmdNOP;
				actr_inc <= 1'b1;
			end

			RD_END2: begin
				actr_inc <= 1'b0;
			end


			WR_BEGIN1: begin
				busin <= 1'b0;
				actr_rst <= 1'b1;
				done <= 1'b0;
			end

			WR_BEGIN2: begin
				actr_rst <= 1'b0;
				ctr_init <= 1'b1;
			end

			WR_CHKEND: begin
				ctr_init <= 1'b0;
			end

			WR_COL1: begin
				dcmd <= cmdACT;
				da   <= actr[DRAM_ROWBNK-1:DRAM_BNK_SIZE];
				dba  <= actr[DRAM_BNK_SIZE-1:0];
			end

			WR_COL2: begin
				dcmd <= cmdNOP;
				ready <= 1'b1;
			end

			WR_COL3: begin
				dcmd <= cmdWRIT;
				da   <= 0;
				dba  <= actr[DRAM_BNK_SIZE-1:0];
			end

			WR_WAIT1: begin
				dcmd <= cmdNOP;
			end

			WR_WAIT2: begin
				ready <= 1'b0;
			end

			WR_BST: begin
				dcmd <= cmdBST;
			end

			WR_PRE: begin
				dcmd <= cmdPRE;
				da   <= 0;
				dba  <= actr[DRAM_BNK_SIZE-1:0];

				actr_inc <= 1'b1;
			end

			WR_END1: begin
				dcmd <= cmdNOP;

				actr_inc <= 1'b0;
				ctr_init <= 1'b1;
			end

		endcase
	end
end

reg [DRAM_DATA_SIZE-1:0] R_DRAM_DQ;
assign DRAM_DQ = busin ? {DRAM_DATA_SIZE{1'bZ}} : R_DRAM_DQ;

always @(posedge clk) begin// read and write data handling
	rdat <= DRAM_DQ;
	R_DRAM_DQ <= wdat;
end


always @(posedge clk) begin
	if( ctr_init ) ctr <= 0;
		else ctr <= ctr + 1'd1;
end


always @(posedge clk) begin
	if( actr_rst ) actr <= 0;
		else if( actr_inc ) actr <= actr + 1'd1;
end


endmodule

