// SPI ST7789 display video XY scan core
// AUTHORS=EMARD,MMICKO and Lawrie Griffiths
// LICENSE=BSD

module lcd_video #(
  parameter ms_cycles = 25000, // kHz clk freq
  parameter C_reset_ms = 128,  // ms holding hardware reset
  parameter C_color_bits = 16, // RGB565
  parameter C_x_size = 240,  // pixel X screen size
  parameter C_y_size = 240,  // pixel Y screen size
  parameter C_x_bits = $clog2(C_x_size),
  parameter C_y_bits = $clog2(C_y_size),
  // file name is relative to directory path in which verilog compiler is running
  // screen can be also XY flipped and/or rotated from this init file
  parameter C_init_file = "st7789_init.mem",
  parameter C_init_size = 36 // bytes in init file
) (
  input  wire clk, // SPI display clock rate will be half of this clock rate
  input  wire reset,
  
  output reg  [C_x_bits-1:0] x,
  output reg  [C_y_bits-1:0] y,
  output reg  next_pixel, // 1 when x/y changes
  input  wire [C_color_bits-1:0] color, 

  output wire oled_csn,
  output wire oled_clk,
  output wire oled_mosi,
  output wire oled_dc,
  output wire oled_resn
);


  reg [7:0] C_oled_init[0:C_init_size-1];
  initial begin
    $readmemh(C_init_file, C_oled_init);
  end

  reg [10:0] init_cnt;
  reg [7:0] data;
  reg dc;
  reg byte_toggle; // alternates data byte for 16-bit mode
  reg init = 1;
  reg [4:0] num_args;
  reg [25:0] delay_cnt = ms_cycles*C_reset_ms; // initial delay is 512ms for reset
  reg [5:0] arg;
  reg delay_set = 0;
  reg [7:0] last_cmd;
  reg resn = 0;

  assign oled_resn = resn;          // Reset is High, Low, High for first 3 cycles
  assign oled_csn = resn;           // Connected to backlight
  assign oled_dc = dc;              // 0 for commands, 1 for command parameters and data
  assign oled_clk = init_cnt[0];    // SPI Mode 2
  assign oled_mosi = data[7];       // Shift out data

  // The next byte in the initialisation sequence
  wire [7:0] next_byte = C_oled_init[init_cnt[10:4]];

  // Do the initialisation sequence and then start sending pixels
  always @(posedge clk) begin
    if (reset) begin
      delay_cnt <= C_reset_ms*ms_cycles;
      delay_set <= 0;
      init_cnt <= 0;
      init <= 1;
      dc <= 0;
      resn <= 0;
      x <= 0;
      y <= 0;
      byte_toggle <= 0;
      arg <= 0;
    end else if (delay_cnt[25] == 0) begin // Delay
      delay_cnt <= delay_cnt - 1;
      resn <= 1;
    end else if (init_cnt[10:4] != C_init_size) begin
      init_cnt <= init_cnt + 1;
      if (init_cnt[3:0] == 0) begin // Start of byte
        if (init) begin // Still initialisation
          dc <= 0;
          arg <= arg + 1;
          if (arg == 0) begin // New command
            data <=  0; // No NOP
            last_cmd <= next_byte;
          end else if (arg == 1) begin // numArgs and delay_set
            num_args <= next_byte[4:0];
            delay_set <= next_byte[7];
            if (next_byte == 0) arg <= 0; // No args or delay
            data <= last_cmd;
          end else if (arg <= num_args + 1) begin // argument
            data <= next_byte;
            dc <= 1;
            if (arg == num_args + 1 && !delay_set) arg <= 0;
          end else if (delay_set) begin // delay
            delay_cnt <= ms_cycles << next_byte;
            data <= 0;
            delay_set <= 0;
            arg <= 0;
          end
        end else begin // Send pixels and set x,y and next_pixel
          byte_toggle <= ~byte_toggle;
          dc <= 1;
          data <= byte_toggle ? color[7:0] : color[15:8];
          if (byte_toggle) begin
            next_pixel <= 1;
            if (x == C_x_size-1) begin
              x <= 0;
              if (y == C_y_size-1)
                y <= 0;
              else
                y <= y + 1;
            end else x <= x + 1;
          end
        end
      end else begin // Shift out byte
        next_pixel <= 0;
        if (init_cnt[0] == 0) data <= { data[6:0], 1'b0 };
      end
    end else begin // Initialisation done, start sending pixels
      init <= 0;
      init_cnt[10:4] <= C_init_size - 1;
    end
  end
endmodule
