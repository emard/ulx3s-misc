`default_nettype none
module collatz_conjecture
#(
parameter standoff = 16, // standoff from max value (MSB zero bits)
parameter bits     = 32  // arithmetic regs size
)
(
input  wire            clk, clken,
output wire            valid,
output wire [bits-1:0] start, actual
);
  
  localparam [standoff-1:0]      zero0 = 0;
  localparam [bits-1-standoff:0] zero1 = 0;
  reg [bits-1:0] r_start  = {zero0,~zero1};
  reg [bits-1:0] r_next   = {zero0,~zero1};
  reg [bits-1:0] r_actual = {zero0,~zero1};
  // x*3+1 = (x*2+1)+x = ((x<<1)|1) + x
  wire [bits-1:0] w_actual_3np1 = {r_actual[bits-2:0],1'b1} + r_actual;
  always @(posedge clk)
    if(clken)
    begin
      r_actual <= |r_actual[bits-1:1] == 0 ? r_next : r_actual[0] ? w_actual_3np1[bits-1:1] : r_actual[bits-1:1];
      r_start  <= |r_actual[bits-1:1] == 0 ? r_next : r_start;
      r_next   <= r_start - 1;
    end
  assign start  = r_start;
  assign actual = r_actual;
  assign valid  = 1;
endmodule
`default_nettype wire
