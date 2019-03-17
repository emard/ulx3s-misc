// SPI OLED SSD1331 display HEX decoder core
// AUTHOR=EMARD
// LICENSE=BSD

// keep en=1 to show OLED screen

module hex_decoder
#(
  parameter C_data_len = 8, // input bits report len
  parameter C_debounce = 1'b0,
  parameter C_font_file = "oled_font.mem",
  parameter C_font_size = 136,
  // Useful values of C_data_len: 4,8,16,32,64,128,192,256,320,448,512
  // Display has 8 lines. Each line has 16 HEX digits or 64 bits.
  // C_data_len(63 downto 0) is shown on the first line
  // C_data_len(127 downto 64) is shown on second line etc.
  parameter C_x_bits = 7, // X screen bits
  parameter C_y_bits = 6  // Y screen bits
)
(
  input  wire clk, // 1-25 MHz clock typical
  input  wire en, // 1-enable/0-hold input for button or other purpose
  input  wire [C_data_len-1:0] data,
  input  wire [C_x_bits-1:0] x,
  input  wire [C_y_bits-1:0] y,
  input  wire next_pixel,
  output wire [7:0] color
);

  wire [4:0] C_oled_font[0:C_font_size-1];
  initial
  begin
    $readmemb(C_font_file, C_oled_font);
  end

  reg [C_data_len-1:0] R_data;

  reg R_dc = 1'b0; // 0-command, 1-data

  localparam C_holding_bits = 23;
  reg [C_holding_bits-1:0] R_holding = 0; // debounce counter
  reg R_go = 1'b1;
  reg [9:0] R_increment = 10'b0000000001; // fitted to start from char index 0

  // alias S_column: std_logic_vector(3 downto 0) is R_increment(3 downto 0);
  wire [3:0] S_column = R_increment[3:0];
  // alias S_scanline: std_logic_vector(2 downto 0) is R_increment(6 downto 4);
  wire [2:0] S_scanline = R_increment[6:4];
  // alias S_row: std_logic_vector(2 downto 0) is R_increment(9 downto 7);
  wire [2:0] S_row = R_increment[9:7];

  reg [2:0] R_cpixel = 1; // fitted to start with first pixel
  localparam C_char_line_bits = 5;
  reg [C_char_line_bits-1:0] R_char_line = 5'b01110;
  // signal R_cpixel: integer range 0 to 6; -- pixel counter
  wire [7:0] S_pixel;
  reg [7:0] R_pixel;

  // type T_screen_line is array(0 to 15) of integer range 0 to 16;
  // type T_screen is array(0 to 7) of T_screen_line;
/*
  signal C_screen: T_screen :=
  ( -- example screen during debugging
    (15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0),
    (0,0,5,0,0,0,0,0,0,0,0,0,0,0,0,0),
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
    (0,0,7,0,0,0,0,0,0,0,0,0,0,0,0,0),
    (0,0,0,0,0,0,16,0,0,15,0,0,0,0,0,0),
    (0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0),
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  );
*/
  reg [6:0] R_data_index = 7'b0000010; // tuned to start at 1st hex digit
  reg [3:0] R_indexed_data; // stored from input
  wire [3:0] S_indexed_data;

  // red   20 40 80
  // green 04 08 10
  // blue  01 02
  localparam C_color_black         = 8'h00;
  localparam C_color_dark_red      = 8'h40;
  localparam C_color_dark_brown    = 8'h44;
  localparam C_color_dark_yellow   = 8'h48;
  localparam C_color_dark_green    = 8'h08;
  localparam C_color_dark_cyan     = 8'h05;
  localparam C_color_dark_blue     = 8'h01;
  localparam C_color_dark_violett  = 8'h21;
  localparam C_color_gray          = 8'h45;
  localparam C_color_light_red     = 8'h80;
  localparam C_color_orange        = 8'h84;
  localparam C_color_light_yellow  = 8'h90;
  localparam C_color_light_green   = 8'h15;
  localparam C_color_light_cyan    = 8'h0A;
  localparam C_color_light_blue    = 8'h02;
  localparam C_color_light_violett = 8'h42;

  wire [7:0] C_color_map[0:15]; // char background color map
  assign C_color_map[0] = C_color_black;
  assign C_color_map[1] = C_color_dark_red;
  assign C_color_map[2] = C_color_dark_brown;
  assign C_color_map[3] = C_color_dark_yellow;
  assign C_color_map[4] = C_color_dark_green;
  assign C_color_map[5] = C_color_dark_cyan;
  assign C_color_map[6] = C_color_dark_blue;
  assign C_color_map[7] = C_color_dark_violett;
  assign C_color_map[8] = C_color_gray;
  assign C_color_map[9] = C_color_light_red;
  assign C_color_map[10] = C_color_orange;
  assign C_color_map[11] = C_color_light_yellow;
  assign C_color_map[12] = C_color_light_green;
  assign C_color_map[13] = C_color_light_cyan;
  assign C_color_map[14] = C_color_light_blue;
  assign C_color_map[15] = C_color_light_violett;
  reg [7:0] R_indexed_color;

  generate
  if(C_debounce == 1'b1)
  always @(posedge clk)
  begin
      if (en == 1'b1)
      begin
        if(R_holding[C_holding_bits-1] == 1'b0)
          R_holding <= R_holding + 1;
      end
      else
        R_holding <= 0;

      // filter out single keypress (10 ms) or hold (1 sec)
      if(R_holding == 65536 || R_holding[C_holding_bits-1] == 1'b1)
        R_go <= 1'b1;
      else
        R_go <= 1'b0;
  end // always
  else
    always @(posedge clk)
      R_go <= en;
  endgenerate

  // S_pixel <= x"FF" when R_char_line(R_char_line'high) = '1' else R_indexed_color; -- scan left to right
  assign S_pixel = R_char_line[0] == 1'b1 ? 8'hFF : R_indexed_color; // scan right to left (white on color background)
  // S_pixel <= x"FF" when R_char_line(0) = '1' else x"00"; -- scan right to left (white on black)
  assign S_indexed_data = R_data[R_data_index*4+3 : R_data_index*4];

  reg [10:0] R_counter;
  always @(posedge clk)
  begin
          if(next_pixel) // next pixel appears every 16th clock cycle 
          begin
            // pixel data
            R_pixel <= S_pixel;
            if(R_cpixel == 3)
              R_data_index <= { S_row, S_column };
            if(R_cpixel == 4)
              R_indexed_data <= S_indexed_data;
            if(R_cpixel == 5) // load new hex digit
            begin
              R_cpixel <= 0;
              // this example shows data correctly
              //R_indexed_color <= C_color_map(C_screen(conv_integer(S_row))(conv_integer(S_column)));
              //R_char_line <= C_oled_font(
              //  C_screen(conv_integer(S_row))(conv_integer(S_column))
              //  )(conv_integer(S_scanline));
              // useable but ugly pixels from signal propagation delays
              R_indexed_color <= C_color_map[R_indexed_data];
              R_char_line <= C_oled_font[R_indexed_data*8 + S_scanline];
              R_increment <= R_increment + 1; // increment for column and scan line
              if(R_increment == 0 && R_go == 1'b1)
                R_data <= data; // sample data
            end
            else
            begin
              // R_char_line <= R_char_line(R_char_line'high-1 downto 0) & '0'; -- scan left to right
              R_char_line <= { 1'b0, R_char_line[C_char_line_bits-1:1] }; // scan right to left
              R_cpixel <= R_cpixel + 1;
            end
          end
  end
  assign color = R_pixel;
endmodule

// TODO
// [x] latch input otherwise broken chars will appear
// [ ] latched datata unreliably displayed, signal propagation delay problem

