//------------------------------------------------------------------------------
//          PCM5102 2 Channel DAC
//------------------------------------------------------------------------------
// http://www.ti.com/product/PCM5101A-Q1/datasheet/specifications#slase121473
module pcm5102
#(
  parameter DAC_CLK_DIV_BITS = 4 // 1 = 384Khz, 2 = 192Khz, 3 = 96Khz, 4 = 48Khz
)
(
  input clk,               // sysclk 100MHz
  input [15:0] left,right, // left and right 16bit samples Uint16
  output reg din,          // pin on pcm5102 data
  output reg bck,          // pin on pcm5102 bit clock
  output reg lrck          // pin on pcm5102 l/r clock can be used outside of this module to create new samples
);

  reg [DAC_CLK_DIV_BITS:0] i2s_clk; // 2 Bit Counter 48MHz -> 6.0 MHz bck = ca 187,5 Khz SampleRate 4% tolerance ok by datasheet
  always @(posedge clk)
  begin
    i2s_clk <= i2s_clk + 1;
  end

  reg [15:0] l2c, r2c;
  always @(negedge i2sword[5])
  begin
    l2c <= left;
    r2c <= right;
  end

  reg [5:0] i2sword; // 6 bit = 16 steps for left + right
  always @(negedge i2s_clk[DAC_CLK_DIV_BITS])
  begin
    lrck <= i2sword[5];
    din <= i2sword[5] ? l2c[i2sword[4:1]] : r2c[i2sword[4:1]]; // blit data bits
    bck <= ~i2sword[0];
    i2sword <= i2sword - 1;
  end
endmodule
