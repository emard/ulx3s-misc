// simplified random number generator
// not very random, it just increments
// counter with constant prime number and shifts

module rnd_vec_gen(
	clk,

	init,

	save,
	restore,
	next,

	out
);

parameter OUT_SIZE = 16; // size of output port

	input clk;

	input init; // positive initialization strobe, synchronous to clock, its length will determine initial state

	input save,restore,next; // strobes for required events: positive, one clock cycle long

	reg init2;

	reg [OUT_SIZE-1:0] counter, storage;

	output [OUT_SIZE-1:0] out;
	assign out = counter;
	
	wire [OUT_SIZE-1:0] counter_add = counter + 36653; // add prime number
	wire [OUT_SIZE-1:0] counter_add_shift = { counter_add[0], counter_add[OUT_SIZE-1:1] };

	always @(posedge clk)
	begin

		init2 <= init;

		if( init && !init2 ) // begin of initialization
		begin
			counter <= 0;
		end
		else if( init && init2 ) // continue of initialization
		begin
			counter <= 0;
		end
		else // no init, normal work
		begin

			if( restore ) // restore event: higher priority
			begin
				counter <= storage;
			end
			else
			begin
				if( next ) // step to next value
				begin
					counter <= counter_add_shift;
				end

				if( save ) // save current state
				begin
					storage <= counter;
				end
			end
		end
	end


endmodule
