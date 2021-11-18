// TODO: stop if actual < start (check only MSB bit)

`default_nettype none
module collatz_conjecture
#(
parameter explore_bits = 20, // nonzero counter bits (cca 2/3 bits) 
parameter endbits      = 68, // bits already explored
parameter bits         = 32  // arithmetic regs width
)
(
input  wire            clk, clken, skip,
output wire            active,
output wire [bits-1:0] start, actual
);
  
  wire [bits-1:0] w_counter;
  reg  [bits-1:0] r_start  = 2;
  reg  [bits-1:0] r_next   = 2;
  reg  [bits-1:0] r_actual = 1;
  // x*3+1 = (x*2+1)+x = ((x<<1)|1) + x
  wire [bits-1:0] w_actual_3np1 = {r_actual[bits-2:0],1'b1} + r_actual;
  wire w_finish = |r_actual[bits-1:endbits] == 1'b0;
  //wire w_finish = r_actual < r_start;
  reg r_finish = 0, inc_counter = 0;
  wire w_skip = skip;
  reg skip_value = 0;
  // r_finish: edge detection
  always @(posedge clk)
  begin
    inc_counter <= (w_finish & ~r_finish) | w_skip;
    r_finish    <= w_finish;
    if(skip_value)
    begin
      if(r_finish == 0)
        skip_value <= 0;
    end
    else // skip_value == 0
    begin
      if(r_finish || w_skip)
        skip_value <= 1;
    end
  end

  always @(posedge clk)
    if(clken)
    begin
      r_actual <= skip_value ? r_next : r_actual[0] ? w_actual_3np1[bits-1:1] : r_actual[bits-1:1];
      r_start  <= skip_value ? r_next : r_start; // for display
    end
  
  // counter increments on the "w_finish" signal edge
  /*
  gray_counter
  #(
    .bits(explore_bits)
  )
  gray_inst
  (
    .clk(clk),
    .reset(1'b0),
    .enable(inc_counter),
    .gray_count(w_counter)
  );

  // invert and reverse order of the counter bits
  // to start nonzero and explore high numbers ending with hex ,,,FFF
  // iterations are larger than starting number
  generate
    genvar i;
    for(i = 0; i < explore_bits; i++)
      always @(posedge clk)
        if(inc_counter)
          r_next[i] <= ~w_counter[explore_bits-1-i];
  endgenerate
  */

  random_counter
  #(
    .bits(explore_bits)
  )
  random_inst
  (
    .clk(clk),
    .reset(1'b0),
    .enable(inc_counter),
    .random(w_counter)
  );

  always @(posedge clk)
    if(inc_counter)
      r_next <= w_counter;

  assign active = skip_value;
  //assign start  = r_next; // debug
  assign start  = r_start;
  assign actual = r_actual;
endmodule
`default_nettype wire
