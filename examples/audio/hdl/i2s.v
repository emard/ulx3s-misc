//------------------------------------------------------------------------------
//           i2s 2 Channel for DAC PCM5102
//------------------------------------------------------------------------------
// http://www.ti.com/product/PCM5101A-Q1/datasheet/specifications#slase121473
module i2s
#(
  parameter    fmt = 0,    // 0:i2s standard, 1:left justified
  parameter    div = 3     // clk:24.576 MHz -> 0:384 kHz, 1:192 kHz, 2:96 kHz, 3:48 kHz
)
(
  input        clk,        // 24.576 MHz, 25 MHz acceptable
  input [15:0] left,right, // PCM 16-bit signed
  output       din,        // pin on pcm5102 data
  output       bck,        // pin on pcm5102 bit clock
  output       lrck        // pin on pcm5102 L/R clock
);
  reg [31:0] i2s_data;
  reg [div+5:0] i2s_cnt; // 6 extra bits, 5 for 32-bit data, 1 for clock
  reg dbit;
  parameter [4:0] latch_phase = fmt ? ~0 : 0;
  always @(posedge clk)
  begin
    if(i2s_cnt[div:0] == 0)
    begin
      if(i2s_cnt[div+5:div+1] == latch_phase)
        i2s_data <= {left,right};
      else
        i2s_data[31:1] <= i2s_data[30:0];
    end
    i2s_cnt <= i2s_cnt + 1;
  end
  assign lrck = fmt ? ~i2s_cnt[div+5] : i2s_cnt[div+5];
  assign bck  = ~i2s_cnt[div];
  assign din  =  i2s_data[31]; // MSB first, but 1 bit delayed after lrck edge
endmodule
