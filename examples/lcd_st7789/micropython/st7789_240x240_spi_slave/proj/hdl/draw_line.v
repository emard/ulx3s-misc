// Bresenham line draw algorithm
// AUTHOR=EMARD
// LICENSE=BSD

// TODO support plotting horizontal and vertical lines

`default_nettype none
module draw_line 
(
  input  wire        clk, // SPI display clock rate will be half of this clock rate
  // line draw signaling
  input  wire        plot, // request plotting a pixel
  output reg         busy = 0, // response to plot
  input  wire [15:0] x0,y0, x1,y1, color, // sampled at rising edge of plot
  // LCD interface (future H/V line)
  output wire        hvline_plot,
  input  wire        hvline_busy,
  output wire [15:0] hvline_x, hvline_y, hvline_len, hvline_color,
  output wire        hvline_vertical
);
  reg [2:0] state = 0;
  reg [15:0] R_x0, R_y0, R_x1, R_y1, R_color;
  reg [15:0] dx, dy, err;
  reg steep, ystep;
  reg R_plot;
  reg [15:0] R_hvx, R_hvy, R_len = 1;
  always @(posedge clk) begin
    if (state == 0) begin // idle
      R_plot <= 0;
      if (plot & ~busy) begin
        R_x0 <= x0;
        R_y0 <= y0;
        R_x1 <= x1;
        R_y1 <= y1;
        R_color <= color;
        dx <= x1>x0 ? x1-x0 : x0-x1;
        dy <= y1>y0 ? y1-y0 : y0-y1;
        busy  <= 1;
        state <= 1;
      end
    end else if (state == 1) begin
      steep <= dy > dx;
      if (dy > dx) begin
        R_x0 <= R_y0;
        R_y0 <= R_x0;
        R_x1 <= R_y1;
        R_y1 <= R_x1;
        dx   <= dy;
        dy   <= dx;
      end
      state <= 2;
    end else if (state == 2) begin
      if (R_x0 > R_x1) begin
        R_x0 <= R_x1;
        R_x1 <= R_x0;
        R_y0 <= R_y1;
        R_y1 <= R_y0;
      end
      err <= dx >> 1;
      state <= 3;
    end else if (state == 3) begin
      ystep <= R_y0 < R_y1; // ystep 1:positive, 0:negative
      R_hvx <= R_x0; // TODO for len
      R_hvy <= R_y0; // TODO for len
      R_len <= 0;
      R_plot <= 1;
      state <= 4;
    end else begin // draw the line
      if (hvline_busy == 0) begin
        if (R_x0 == R_x1) begin
          busy <= 0;
          state <= 0;
          R_plot <= 0;
        end else begin
          if (err < dy) begin // negative?
            // TODO draw horizontal/vertical line
            if (ystep)
              R_y0 <= R_y0+1;
            else
              R_y0 <= R_y0-1;
            err <= err - dy + dx;
            R_len <= 0;
          end else begin
            err <= err - dy;
            R_len <= R_len+1;
          end
          R_x0 <= R_x0+1;
          R_plot <= 1;
        end
      end
    end
  end

  assign hvline_plot = R_plot;
  assign hvline_x = steep ? R_y0 : R_x0;
  assign hvline_y = steep ? R_x0 : R_y0;
  assign hvline_color = R_color;
  assign hvline_len = 1; // TODO H/V line
  assign hvline_vertical = steep; // TODO H/V line

endmodule
