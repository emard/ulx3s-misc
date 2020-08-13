// Bresenham line draw algorithm
// AUTHOR=EMARD
// LICENSE=BSD

`default_nettype none
module draw_line 
(
  input  wire clk, // SPI display clock rate will be half of this clock rate

  input  wire plot, // request plotting a pixel
  output reg  busy, // response to plot

  input  wire [15:0] x0,y0, x1,y1, color,

  output wire pixel_plot,
  input  wire pixel_busy,
  output reg [15:0] pixel_x, pixel_y, pixel_color
);
  reg [15:0] R_x0,R_y0, R_x1,R_y1;

  always @(posedge clk) begin
    if (plot & ~busy) begin
      R_x0 <= x0;
      R_y0 <= y0;
      R_x1 <= x1;
      R_y1 <= y1;
      pixel_color <= color;
      pixel_x <= x0;
      pixel_y <= y0;
      pixel_plot <= 1;
      busy <= 1;
    end else begin
      pixel_plot <= 0;
      if (pixel_busy == 0) begin
        busy <= 0;
      end
    end
  end

endmodule
