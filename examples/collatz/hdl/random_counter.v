`default_nettype none
module random_counter
#(
  parameter accu_bits = 48, // internal accumulator is pseudo random number, prime number added
  parameter accu_rot  = 24, // how many bits to rotate-right before add
  parameter [47:0] prime_add = 48'd6692367337, // prime number add to accu
  parameter bits = 128
)
(
  input  wire            clk,
  input  wire            reset, // not used
  input  wire            enable,
  output wire [bits-1:0] random
);

  reg [accu_bits-1:0] r_accu = ~prime_add; // the random accumulatoor
  always @(posedge clk)
  begin
    if(enable)
      r_accu <= {r_accu[accu_rot-1:0], r_accu[accu_bits-1:accu_rot]} + prime_add; // rotate and add the prime number
  end
  
  reg r_random[0:bits-1]; // RAM 1-bit wide
  reg flip_bit;
  always @(posedge clk)
  begin
    if(enable)
      r_random[r_accu] <= flip_bit;
    else
      flip_bit <= ~r_random[r_accu];    
  end

  wire [bits-1:0] w_random;
  generate
    genvar i;
    for(i = 0; i < bits; i = i+1)
      assign w_random[i] = r_random[i];
  endgenerate

  assign random = ~w_random;
  //assign random = r_accu; // debug

endmodule
`default_nettype wire
