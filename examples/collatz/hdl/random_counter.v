`default_nettype none
module random_counter
#(
  parameter n_ring_osc = 7, // number of ring oscillators
  parameter bits = 128
)
(
  input  wire            clk,
  input  wire            enable,
  output wire [bits-1:0] random
);

  // odd number of inverters (NOT gates) in the ring make the ring oscillator
  // it can be a single inverter connected to itself
  wire [n_ring_osc-1:0] w_ring;
  localparam [15:0] INVERTER = 16'h0001; // LUT4 init as inverter Z = NOT A
  generate
    genvar i;
    for(i = 0; i < n_ring_osc; i++)
      LUT4 #(.INIT(INVERTER)) inverter_inst (.Z(w_ring[i]), .A(w_ring[i]), .B(0), .C(0), .D(0));
  endgenerate

  reg [n_ring_osc-1:0] r_accu; // hold the random number
  always @(posedge clk)
  begin
    if(enable)
      r_accu <= w_ring;
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
    for(i = 0; i < bits; i++)
      assign w_random[i] = r_random[i];
  endgenerate

  assign random = ~w_random;
  //assign random = r_accu; // debug

endmodule
`default_nettype wire
