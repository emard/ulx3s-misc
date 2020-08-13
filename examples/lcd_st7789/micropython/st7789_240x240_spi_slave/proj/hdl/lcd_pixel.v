// SPI ST7789 display core with line draw GPU
// AUTHOR=EMARD
// LICENSE=BSD
`default_nettype none
module lcd_pixel #(
  parameter c_clk_mhz = 25, // MHz clk freq (125 MHz max for st7789)
  parameter c_reset_us = 150000, // us holding hardware reset
  parameter c_color_bits = 16, // RGB565 don't touch
  //parameter c_x_size = 240,  // pixel X screen size
  //parameter c_y_size = 240,  // pixel Y screen size
  //parameter c_x_bits = $clog2(c_x_size), // 240->8
  //parameter c_y_bits = $clog2(c_y_size), // 240->8
  parameter c_clk_phase = 0, // spi_clk phase
  parameter c_clk_polarity = 1, // spi_clk polarity and idle state 0:normal, 1:inverted (for st7789)
  // file name is relative to directory path in which verilog compiler is running
  // screen can be also XY flipped and/or rotated from this init file
  parameter c_init_file = "st7789_linit_pixel.mem",
  parameter c_pixel_start = 24, // initialize index from here to skip init and draw pixel
  parameter c_x_addr = 26, // MSB LSB MSB LSB 4 bytes
  parameter c_y_addr = 32, // MSB LSB MSB LSB 4 bytes
  parameter c_color_addr = 38, // MSB LSB 2 bytes
  parameter c_init_size = 40, // bytes in init file
  // although SPI CLK will be stopped during
  // arg parsing and delays, to be on the safe side
  // this will put NOP command at SPI MOSI line
  parameter c_nop = 8'h00 // NOP command from datasheet
) (
  input  wire clk, // SPI display clock rate will be half of this clock rate
  input  wire clk_pixel_ena = 1,
  input  wire reset,

  input  wire plot, // request plotting a pixel
  output wire busy, // response to plot

  input  wire [15:0] x, y, color,

  output wire spi_csn,
  output wire spi_clk,
  output wire spi_mosi,
  output wire spi_dc,
  output wire spi_resn
);

  reg [7:0] c_lcd_buf[0:c_init_size-1];
  initial begin
    $readmemh(c_init_file, c_lcd_buf);
  end

  reg [15:0] R_x, R_y, R_color;

  reg [10:0] index;
  reg [7:0] data = c_nop;
  reg dc = 1;
  reg byte_toggle; // alternates data byte for 16-bit mode
  reg init = 1;
  reg [4:0] num_args;
  reg [27:0] delay_cnt = c_clk_mhz*c_reset_us; // initial delay fits 1.3s at 100MHz
  reg [5:0] arg;
  reg delay_set = 0;
  reg [7:0] last_cmd;
  reg resn = 0;
  reg clken = 0;

  // The next byte in the initialisation sequence
  wire [7:0] next_byte = c_lcd_buf[index[10:4]];

  // Do the initialisation sequence and then start sending pixels
  always @(posedge clk) begin
    if (reset) begin
      delay_cnt <= c_reset_us*c_clk_mhz;
      delay_set <= 0;
      index <= 0;
      init <= 1;
      dc <= 1;
      resn <= 0;
      byte_toggle <= 0;
      arg <= 1; // after reset, before commands take delay from init sequence
      data <= c_nop;
      clken <= 0;
    end else if (delay_cnt[$bits(delay_cnt)-1] == 0) begin // Delay
      delay_cnt <= delay_cnt - 1;
      resn <= 1;
    end else if (plot & ~init) begin
      index[10:4] <= c_pixel_start;
      index[3:0] <= 0;
      init <= 1;
      arg <= 0;
      R_x <= x;
      R_y <= y;
      R_color <= color;
    end else if (index[10:4] != c_init_size) begin
      index <= index + 1;
      if (index[3:0] == 0) begin // Start of byte
        if (init) begin // Still initialisation
          dc <= 0;
          arg <= arg + 1;
          if (arg == 0) begin // New command
            data <= c_nop; // No NOP
            clken <= 0;
            last_cmd <= next_byte;
          end else if (arg == 1) begin // numArgs and delay_set
            num_args <= next_byte[4:0]+1;
            delay_set <= next_byte[7];
            if (next_byte == 0) arg <= 0; // No args or delay
            data <= last_cmd;
            clken <= 1;
          end else if (arg <= num_args) begin // argument
            if      (index[10:4]==c_x_addr   || index[10:4]==c_x_addr+2)
              data <= R_x[15:8]; // X MSB
            else if (index[10:4]==c_x_addr+1 || index[10:4]==c_x_addr+3)
              data <= R_x[7:0];  // X LSB
            else if (index[10:4]==c_y_addr   || index[10:4]==c_y_addr+2)
              data <= R_y[15:8]; // Y MSB
            else if (index[10:4]==c_y_addr+1 || index[10:4]==c_y_addr+3)
              data <= R_y[7:0];  // Y LSB
            else if (index[10:4]==c_color_addr)
              data <= R_color[15:8]; // COLOR MSB
            else if (index[10:4]==c_color_addr+1)
              data <= R_color[7:0]; // COLOR LSB
            else
              data <= next_byte;
            clken <= 1;
            dc <= 1;
            if (arg == num_args && !delay_set) arg <= 0;
          end else if (delay_set) begin // delay
            delay_cnt <= c_clk_mhz << (next_byte[4:0]); // 2^n us delay
            data <= c_nop;
            clken <= 0;
            delay_set <= 0;
            arg <= 0;
          end
        end else begin // init done, stop
          clken <= 0;
        end
      end else begin // Shift out byte
        if (index[0] == 0) data <= { data[6:0], 1'b0 };
      end
    end else begin // Initialisation done, stop
      dc <= 0;
      clken <= 0;
      data <= c_nop;
      init <= 0;
      //index[10:4] <= 0;
    end
  end

  assign busy = init;
  assign spi_resn = resn;             // Reset is High, Low, High for first 3 cycles
  assign spi_csn = ~clken;            // not used for st7789
  assign spi_dc = dc;                 // 0 for commands, 1 for command parameters and data
  assign spi_clk = ( (index[0] ^ ~c_clk_phase) | ~clken) ^ ~c_clk_polarity; // stop clock during arg and delay
  assign spi_mosi = data[7];          // Shift out data

endmodule
