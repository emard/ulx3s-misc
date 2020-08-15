// Bresenham line draw algorithm
// AUTHOR=EMARD
// LICENSE=BSD

// ST7789 polyline draw interface
// input: BRAM interface with
// list of coordinates x,y (32-bit tota, each x and y are 16-bit)
// at rising edge of plot, drawing polyline starts (busy=1)
// this module will address the buffer and draw lines.
// otput is SPI bus, directly connected to display
// LCD display will be initialized first time when
// bitstream is loaded or at any later time by "reset" signal.

// TODO
// if X MSB bit is set, end one polyline and start next polyline
// if Y MSB bit is set, end polyline data and execute (no need for length)

`default_nettype none
module draw_polyline 
#(
  parameter c_clk_mhz = 125 // input clk frequency 128 MHz max
  // SPI display driver should know this for initialization delays
  // ST7789 spi_clk max is 64 MHz
  // spi_clk = clk/2
  // clk max is 128 MHz
  // in practice on ECP5 this core works up to clk = 100 MHz
)
(
  input  wire        clk, // SPI display clock rate will be half of this clock rate
  input  wire        reset, // re-initialize SPI display
  // line draw signaling
  input  wire        plot, // request plotting the polyline
  output reg         busy = 0, // response to plot
  input  wire  [8:0] len, // how many x,y pairs to plot
  input  wire [15:0] data, color, // sampled at rising edge of plot
  output wire  [9:0] addr, // for 2KB buffer (1024x16-bit)
  output wire        rd,   // BRAM read cycle (usally not needed)
  output wire [15:0] x0,y0, // DEBUG
  // LCD ST7789 interface (SPI)
  output wire spi_csn, // 7-pin ST7789 needs constant 1 for backlight instead of csn
  output wire spi_clk,
  output wire spi_mosi,
  output wire spi_dc,
  output wire spi_resn
);
  reg [2:0] state = 0;
  reg full; // 1: enough data for one line
  reg [15:0] R_color;
  reg [9:0] R_len, R_addr;
  // coordinate buffer for one line
  reg [15:0] R_line[0:3];
  // line signals
  reg  R_line_plot;
  wire line_busy;
  always @(posedge clk) begin
    if (reset) begin
      state <= 0;
      busy  <= 0;
      R_addr <= 0;
    end else if (state == 0) begin // idle
      if (plot & ~busy) begin
        R_color <= color;
        R_len   <= {len,1'b0}; // len*2
        R_addr  <= 0;
        busy    <= 1;
        full    <= 0; // for first point, line is not full
        R_line_plot <= 0;
        state   <= 1;
      end
    end else if (state == 1) begin // dummy cycle to get ram data ready
      state <= 2;
    end else if (state == 2) begin
      if (R_addr != R_len) begin
        R_line[R_addr[1:0]] <= data;
        R_addr <= R_addr+1;
        state <= 1; // to dummy cycle
        if (R_addr[0]) begin // every odd addr
          if (full)
            state <= 3; // draw the line
          full <= 1;
        end
      end else begin
        busy <= 0;
        state <= 0;
      end
    end else if (state == 3) begin // wait for busy off
      if (line_busy == 0) begin
        R_line_plot <= 1;
        state <= 4;
      end
    end else begin // wait for busy on - plot accepted
      if (line_busy) begin
        R_line_plot <= 0;
        state <= 2; // read next data
      end
    end
  end
  assign addr = R_addr;

  wire [15:0] hvline_x, hvline_y, hvline_len, hvline_color;
  wire hvline_vertical, hvline_plot, hvline_busy;

  assign x0 = R_line[0]; // DEBUG
  assign y0 = R_line[1];
  
  draw_line
  draw_line_inst
  (
    .clk(clk),
    .plot(R_line_plot),
    .busy(line_busy),
    .x0(R_line[0]),
    .y0(R_line[1]),
    .x1(R_line[2]),
    .y1(R_line[3]),
    .color(R_color),
    .hvline_plot(hvline_plot),
    .hvline_busy(hvline_busy),
    .hvline_x(hvline_x),
    .hvline_y(hvline_y),
    .hvline_len(hvline_len),
    .hvline_vertical(hvline_vertical),
    .hvline_color(hvline_color)
  );

  lcd_hvline
  #(
    .c_clk_mhz(c_clk_mhz),
    .c_init_file("st7789_linit_pixels.mem"),
    .c_clk_phase(0),
    .c_clk_polarity(1)
  )
  lcd_hvline_inst
  (
    .clk(clk),
    .reset(reset),
    .plot(hvline_plot),
    .busy(hvline_busy),
    .x(hvline_x),
    .y(hvline_y),
    .len(hvline_len),
    .vertical(hvline_vertical),
    .color(hvline_color),
    .spi_clk(spi_clk),
    .spi_mosi(spi_mosi),
    .spi_dc(spi_dc),
    .spi_resn(spi_resn),
    .spi_csn(spi_csn)
  );

endmodule
