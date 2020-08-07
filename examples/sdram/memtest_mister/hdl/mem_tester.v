/*

reset...init...save.start_write.stop_write.restore.start_read(compare).stop_read.loop

error...

*/

module mem_tester
#(
  parameter DRAM_DATA_SIZE = 16,
  parameter DRAM_COL_SIZE = 9,
  parameter DRAM_ROW_SIZE = 13
)
(
	input clk,
	input rst_n,

	output reg [31:0] passcount,
	output reg [31:0] failcount,

	output [3:0] mmtst_state,
	output [5:0] sdram_state,

	inout  [DRAM_DATA_SIZE-1:0] DRAM_DQ,
	output [DRAM_ROW_SIZE-1:0] DRAM_ADDR,

	output DRAM_LDQM,DRAM_UDQM,
	output DRAM_WE_N,
	output DRAM_CAS_N,
	output DRAM_RAS_N,
	output DRAM_CS_N,
	output DRAM_BA_0,
	output DRAM_BA_1
);

assign mmtst_state = curr_state;

reg inc_pass_ctr; // increment passes counter
reg inc_err_ctr;  // increment errors counter
reg check_in_progress; // when 1 - enables errors checking


always @(posedge clk, negedge rst_n)
	if( !rst_n ) passcount <= 32'd0;
		else if( inc_pass_ctr ) passcount <= passcount + 32'd1;

always @(posedge clk,negedge rst_n)
	if ( !rst_n ) failcount <= 32'd0;
		else if( inc_err_ctr ) failcount <= failcount + 32'd1;


reg rnd_init,rnd_save,rnd_restore; // rnd_vec_gen control
wire [DRAM_DATA_SIZE-1:0] rnd_out; // rnd_vec_gen output
wire dram_ready;
rnd_vec_gen my_rnd
(
	.clk(clk),
	.init(rnd_init),
	.next(dram_ready),
	.save(rnd_save),
	.restore(rnd_restore),
	.out(rnd_out)
);
defparam my_rnd.OUT_SIZE = DRAM_DATA_SIZE;


reg dram_start;
reg dram_start,dram_rnw;
wire dram_done,dram_ready;
wire [DRAM_DATA_SIZE-1:0] dram_rdat;



// FIXME combinatorial loop in sdram_control
sdram_control my_dram
(
	.rst_n(rst_n),
	.clk(clk),
	.start(dram_start),
	.rnw(dram_rnw),
	.done(dram_done),
	.ready(dram_ready),
	.rdat(dram_rdat),
	.wdat(rnd_out),
	.sdram_state(sdram_state),
	.DRAM_DQ(DRAM_DQ),
	.DRAM_ADDR(DRAM_ADDR),
	.DRAM_CS_N(DRAM_CS_N),
	.DRAM_RAS_N(DRAM_RAS_N),
	.DRAM_CAS_N(DRAM_CAS_N),
	.DRAM_WE_N(DRAM_WE_N),
	.DRAM_LDQM(DRAM_LDQM),
	.DRAM_UDQM(DRAM_UDQM),
	.DRAM_BA_0(DRAM_BA_0),
	.DRAM_BA_1(DRAM_BA_1)
);
defparam my_dram.DRAM_DATA_SIZE = DRAM_DATA_SIZE;
defparam my_dram.DRAM_COL_SIZE  = DRAM_COL_SIZE;
defparam my_dram.DRAM_ROW_SIZE  = DRAM_ROW_SIZE;




// FSM states and registers
reg [3:0] curr_state,next_state;

parameter RESET        = 4'h0;

parameter INIT1        = 4'h1;
parameter INIT2        = 4'h2;

parameter BEGIN_WRITE1 = 4'h3;
parameter BEGIN_WRITE2 = 4'h4;
parameter BEGIN_WRITE3 = 4'h5;
parameter BEGIN_WRITE4 = 4'h6;

parameter WRITE        = 4'h7;

parameter BEGIN_READ1  = 4'h8;
parameter BEGIN_READ2  = 4'h9;
parameter BEGIN_READ3  = 4'hA;
parameter BEGIN_READ4  = 4'hB;

parameter READ         = 4'hC;

parameter END_READ     = 4'hD;

parameter INC_PASSES1  = 4'hE;
parameter INC_PASSES2  = 4'hF;


// FSM dispatcher

always @* begin
	case( curr_state )

		RESET:        next_state <= INIT1;
		INIT1:
				if( dram_done )
					next_state <= INIT2;
				else
					next_state <= INIT1;

		INIT2:        next_state <= BEGIN_WRITE1;
		BEGIN_WRITE1: next_state <= BEGIN_WRITE2;
		BEGIN_WRITE2: next_state <= BEGIN_WRITE3;
		BEGIN_WRITE3: next_state <= BEGIN_WRITE4;
		BEGIN_WRITE4: next_state <= WRITE;
		WRITE:
				if( dram_done )
					next_state <= BEGIN_READ1;
				else
					next_state <= WRITE;

		BEGIN_READ1: next_state <= BEGIN_READ2;
		BEGIN_READ2: next_state <= BEGIN_READ3;
		BEGIN_READ3: next_state <= BEGIN_READ4;
		BEGIN_READ4: next_state <= READ;
		READ:
				if( dram_done )
				  next_state <= END_READ;
				else
				  next_state <= READ;

		END_READ:    next_state <= INC_PASSES1;
		INC_PASSES1: next_state <= INC_PASSES2;
		INC_PASSES2: next_state <= BEGIN_WRITE1;

		default: next_state <= RESET;
	endcase
end


// FSM sequencer
always @(posedge clk,negedge rst_n)
begin
	if( !rst_n )
		curr_state <= RESET;
	else
		curr_state <= next_state;
end


// FSM controller
always @(posedge clk) begin
    case( curr_state )

//////////////////////////////////////////////////
    RESET:
    begin
      // various initializings begin

      inc_pass_ctr <= 1'b0;

      check_in_progress <= 1'b0;

      rnd_init <= 1'b1; //begin RND init

      rnd_save <= 1'b0;
      rnd_restore <= 1'b0;

      dram_start <= 1'b0;
    end

    INIT1:
    begin
      dram_start <= 1'b0; // end dram start
    end

    INIT2:
    begin
      rnd_init <= 1'b0; // end rnd init
    end



//////////////////////////////////////////////////
    BEGIN_WRITE1:
    begin
      rnd_save <= 1'b1;
      dram_rnw <= 1'b0;
    end

    BEGIN_WRITE2:
    begin
      rnd_save   <= 1'b0;
      dram_start <= 1'b1;
    end

    BEGIN_WRITE3:
    begin
      dram_start <= 1'b0;
    end

/*    BEGIN_WRITE4:
    begin
      rnd_save   <= 1'b0;
      dram_start <= 1'b1;
    end

    WRITE:
    begin
      dram_start <= 1'b0;
    end
*/



//////////////////////////////////////////////////
    BEGIN_READ1:
    begin
      rnd_restore <= 1'b1;
      dram_rnw <= 1'b1;
    end

    BEGIN_READ2:
    begin
      rnd_restore <= 1'b0;
      dram_start <= 1'b1;
    end

    BEGIN_READ3:
    begin
      dram_start <= 1'b0;
      check_in_progress <= 1'b1;
    end

/*    BEGIN_READ4:
    begin
      rnd_restore <= 1'b0;
      dram_start <= 1'b1;
    end

    READ:
    begin
      dram_start <= 1'b0;
      check_in_progress <= 1'b1;
    end
*/
    END_READ:
    begin
      check_in_progress <= 1'b0;
    end

    INC_PASSES1:
    begin
      inc_pass_ctr <= 1'b1;
    end

    INC_PASSES2:
    begin
      inc_pass_ctr <= 1'b0;
    end


    endcase
end

// errors counter
always @(posedge clk) inc_err_ctr <= check_in_progress & dram_ready & (( dram_rdat==rnd_out )?1'b0:1'b1);

endmodule
