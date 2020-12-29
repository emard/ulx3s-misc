// Quartus Prime Verilog Template
// True Dual Port RAM with dual clocks
// File->New File->VHDL File
// Edit->Insert Template->VHDL->Full designs->RAMs and ROMs->True dual port RAM (dual clock)

module bram_true2p_2clk
#(
  parameter dual_port = 1,
  parameter data_width = 8,
  parameter addr_width = 6,
  parameter pass_thru_a = 0, // unused
  parameter pass_thru_b = 0, // unused
  parameter initial_file = ""
)
(
  input [(data_width-1):0] data_in_a, data_in_b,
  input [(addr_width-1):0] addr_a, addr_b,
  input we_a, we_b, clk_a, clk_b, clken_a, clken_b,
  output reg [(data_width-1):0] data_out_a, data_out_b
);
  // Declare the RAM variable
  reg [data_width-1:0] ram[2**addr_width-1:0];
  generate
    if(initial_file != "")
      initial $readmemh(initial_file, ram);
  endgenerate

  always @(posedge clk_a)
  begin
    // Port A
    if(clken_a)
    begin
      if(we_a)
      begin
        ram[addr_a] <= data_in_a;
        data_out_a <= data_in_a;
      end
      else
      begin
        data_out_a <= ram[addr_a];
      end
    end
  end

  generate
  if(dual_port)
  always @(posedge clk_b)
  begin
    // Port B
    if(clken_b)
    begin
      if(we_b)
      begin
        ram[addr_b] <= data_in_b;
        data_out_b <= data_in_b;
      end
      else
      begin
        data_out_b <= ram[addr_b];
      end
    end
  end
  endgenerate
endmodule
