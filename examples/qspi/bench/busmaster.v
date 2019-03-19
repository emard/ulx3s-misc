// simple bus master example from
// https://zipcpu.com/blog/2017/06/08/simple-wb-master.html

// this module is incomplete, never compiled,
// probably full of syntax errors.

module busmaster
#(
  parameter ADDRESS_WIDTH = 22,
  parameter AW = ADDRESS_WIDTH-2
)
(
  input i_clk,
  input i_reset, i_wb_err, i_wb_stall, i_wb_ack, i_cmd_bus, i_cmd_wr,
  input [AW-1:0] i_cmd_word,
  input [31:0] i_cmd_addr,
  output [AW-1:0] o_wb_addr,
  output o_wb_cyc, o_wb_stb, o_wb_we, o_cmd_busy
);
	initial	o_wb_cyc = 1'b0;
	initial	o_wb_stb = 1'b0;
	always @(posedge i_clk)
	if ((i_reset)||((i_wb_err)&&(o_wb_cyc)))
	begin
		// On any error or reset, then clear the bus.
		o_wb_cyc <= 1'b0;
		o_wb_stb <= 1'b0;
	end else if (o_wb_stb)
	begin
		//
		// BUS REQUEST state
		//
		if (!i_wb_stall)
			// If we are only going to do one transaction,
			// then as soon as the stall line is lowered, we are
			// done.
			o_wb_stb <= 1'b0;

		// While not likely, it is possible that a slave might ACK
		// our request on the same clock it is received.  In that
		// case, drop the CYC line.
		//
		// We gate this with the stall line in case we receive an
		// ACK while our request has yet to go out.  This may make
		// more sense later, when we are sending multiple back to back
		// requests across the bus, but we'll leave this gate here
		// as a placeholder until then.
		if ((!i_wb_stall)&&(i_wb_ack))
			o_wb_cyc <= 1'b0;
	end else if (o_wb_cyc)
	begin
		//
		// BUS WAIT
		//
		if (i_wb_ack)
			// Once the slave acknowledges our request, we are done.
			o_wb_cyc <= 1'b0;
	end else begin
		//
		// IDLE state
		//
		if (i_cmd_bus)
		begin
			// We've been asked to start a bus cycle from our
			// command word, either RD or WR
			o_wb_cyc <= 1'b1;
			o_wb_stb <= 1'b1;
		end
	end

	// For now, we'll use the bus cycle line as an indication of whether
	// or not we are too busy to accept anything else from the command
	// port.  This will change if we want to accept multiple write
	// commands per bus cycle, but that will be a bus master that's
	// not nearly so simple.
	assign	o_cmd_busy = o_wb_cyc;

	always @(posedge i_clk)
		if (!o_wb_cyc)
			o_wb_we <= (i_cmd_wr);

	//
	// The bus ADDRESS lines
	//
	initial	newaddr = 1'b0;
	always @(posedge i_clk)
	begin
		if ((i_cmd_addr)&&(!o_cmd_busy))
		begin
			// If we are in the idle state, we accept address
			// setting commands.  Specifically, we'll allow the
			// user to either set the address, or add a difference
			// to our address.  The difference may not make sense
			// now, but if we ever wish to compress our command bus,
			// sending an address difference can drastically cut
			// down the number of bits required in a set address
			// request.
			if (!i_cmd_word[1])
				o_wb_addr <= i_cmd_word[31:2];
			else
				o_wb_addr <= i_cmd_word[31:2] + o_wb_addr;

			//
			// We'll allow that bus requests can either increment
			// the address, or leave it the same.  One bit in the
			// command word will tell us which, and we'll set this
			// bit on any set address command.
			inc <= !i_cmd_word[0];
		end else if ((o_wb_stb)&&(!i_wb_stall))
			// The address lines are used while the bus is active,
			// and referenced any time STB && !STALL are true.
			//
			// However, once STB and !STALL are both true, then the
			// bus is ready to move to the next request.  Hence,
			// we add our increment (one or zero) here.
			o_wb_addr <= o_wb_addr + , inc};


		// We'd like to respond to the bus with any address we just
		// set.  The goal here is that, upon any read from the bus,
		// we should be able to know what address the bus was set to.
		// For this reason, we want to return the bus address up the
		// command stream.
		//
		// The problem is that the add (above) when setting the address
		// takes a clock to do.  Hence, we'll use "newaddr" as a flag
		// that o_wb_addr has a new value in it that needs to be
		// returned via the command link.
		newaddr <= ((i_cmd_addr)&&(!o_cmd_busy));
	end

	always @(posedge i_clk)
	begin
		// This may look a touch confusing ... what's important is that:
		//
		// 1. No one cares what the bus data lines are, unless we are
		//	in the middle of a write cycle.
		// 2. Even during a write cycle, these lines are don't cares
		//	if the STB line is low, indicating no more requests
		// 3. When a request is received to write, and so we transition
		//	to a bus write cycle, that request will come with data.
		// 4. Hence, we set the data words in the IDLE state on the
		//	same clock we go to BUS REQUEST.  While in BUS REQUEST,
		//	these lines cannot change until the slave has accepted
		//	our inputs.
		//
		// Thus we force these lines to be constant any time STB and
		// STALL are both true, but set them otherwise.
		//
		if ((!o_wb_stb)||(!i_wb_stall))
			o_wb_data <= i_cmd_word[31:0];
	end

	always @(posedge i_clk)
	if (i_reset)
	begin
		o_rsp_stb <= 1'b1;
		o_rsp_word <= `RSP_RESET;
	end else if (i_wb_err)
	begin
		o_rsp_stb <= 1'b1;
		o_rsp_word <= `RSP_BUS_ERROR;
	end else if (o_wb_cyc) begin
		//
		// We're either in the BUS REQUEST or BUS WAIT states
		//
		// Either way, we want to return a response on our command
		// channel if anything gets ack'd
		o_rsp_stb <= (i_wb_ack);
		//
		//
		if (o_wb_we)
			o_rsp_word <= `RSP_WRITE_ACKNOWLEDGEMENT;
		else
			o_rsp_word <= { `RSP_SUB_DATA, i_wb_data };
	end else begin
		//
		// We are in the IDLE state.
		//
		// Echo any new addresses back up the command chain
		//
		o_rsp_stb  <= newaddr;
		o_rsp_word <= { `RSP_SUB_ADDR, o_wb_addr, 1'b0, !inc };
	end
endmodule
