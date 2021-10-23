// TODO: stop if actual < start (check only MSB bit)

`default_nettype none
module collatz_conjecture
#(
parameter msb0_bits = 16, // msb0_bits from max value (MSB zero bits)
//parameter endbits  =  1, // bits already explored, we know it goes to 1
parameter bits     = 32  // arithmetic regs size
)
(
input  wire            clk, clken,
output wire [bits-1:0] start, actual
);
  
  localparam [msb0_bits-1:0]      zero0 = 0;
  localparam [bits-1-msb0_bits:0] zero1 = 0;
  wire [bits-1:0] w_counter;
  reg  [bits-1:0] r_start  = 2;
  reg  [bits-1:0] r_actual = 1;
  // x*3+1 = (x*2+1)+x = ((x<<1)|1) + x
  wire [bits-1:0] w_actual_3np1 = {r_actual[bits-2:0],1'b1} + r_actual;
  // wire w_finish = |r_actual[bits-1:endbits] == 1'b0;
  wire w_finish = r_actual < r_start;
  reg r_finish = 0, inc_counter = 0;
  // r_finish: edge detection
  always @(posedge clk)
  begin
    inc_counter <= w_finish & ~r_finish;
    r_finish    <= w_finish;
  end

  always @(posedge clk)
    if(clken)
      r_actual <= r_finish ? r_start : r_actual[0] ? w_actual_3np1[bits-1:1] : r_actual[bits-1:1];
  
  // counter increments on the "w_finish" signal edge
  gray_counter
  #(
    .bits(bits-msb0_bits)
  )
  gray_inst
  (
    .clk(clk),
    .reset(1'b0),
    .enable(inc_counter),
    .gray_count(w_counter)
  );

  // starts with first "msb0_bits" bits 0, other 1
  /*
  always @(posedge clk)
    if(inc_counter)
      r_start <= {w_counter[bits-1:bits-msb0_bits], ~w_counter[bits-msb0_bits-1:0]};
  */

  // reverse order of the counter bits
  generate
    genvar i;
    for(i = 0; i < bits-msb0_bits; i++)
      always @(posedge clk)
        if(inc_counter)
          r_start[i] <= ~w_counter[bits-msb0_bits-1-i];
  endgenerate

  assign start  = r_start;
  assign actual = r_actual;
endmodule
`default_nettype wire
