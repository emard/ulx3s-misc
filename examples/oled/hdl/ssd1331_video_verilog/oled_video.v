// SPI OLED SSD1331 display video XY scan core
// AUTHORS=EMARD,MMICKO
// LICENSE=BSD

module oled_video
#(
  // file name is relative to directory path in which verilog compiler is running
  // screen can be also XY flipped and/or rotated from this init file
  parameter c_init_file = "oled_init.mem",
  parameter c_init_size = 44, // bytes in init file
  parameter c_color_bits = 8, // 8 or 16 color depth (should match init file)
  parameter c_x_size = 96,  // pixel X screen size (don't touch)
  parameter c_y_size = 64,  // pixel Y screen size (don't touch)
  parameter c_x_bits = $clog2(c_x_size), // 96->7, fits X screen size (don't touch)
  parameter c_y_bits = $clog2(c_y_size)  // 64->6, fits X screen size (don't touch)
)
(
  input  wire clk, // SPI display clock rate will be half of this clock rate
  input  wire reset,

  output reg  [c_x_bits-1:0] x,
  output reg  [c_y_bits-1:0] y,
  output reg  next_pixel, // 1 when x/y changes
  input  wire [c_color_bits-1:0] color, // color = f(x,y) {3'bRRR, 3'bGGG, 2'bBB }

  output wire spi_csn,
  output wire spi_clk,
  output wire spi_mosi,
  output wire spi_dc,
  output wire spi_resn
);

  // "wire" should be used instead of "reg" because it's ROM.
  // trellis works with either "wire" or "reg"
  // diamond works only with "reg"
  reg [7:0] c_spi_init[0:c_init_size-1];
  initial
  begin
    $readmemh(c_init_file, c_spi_init);
  end

  reg [1:0] reset_cnt;
  reg [9:0] index;
  reg [7:0] data;
  reg dc;

  reg R_byte; // alternates data R_byte for 16-bit mode
  wire [7:0] color_to_data;
  generate
    if(c_color_bits < 12)
      assign color_to_data = color;
    else
      assign color_to_data = R_byte ? color[15:8] : color[7:0];
  endgenerate
  reg [7:0] datalow; // LSB byte of 16-bit data transfer

  always @(posedge clk) begin
      if (reset)
        reset_cnt <= 2'b00;
      else
      begin
        if (reset_cnt != 2'b10) 
        begin
            reset_cnt <= reset_cnt+1;
            index <= 10'd0;
            data <= c_spi_init[0];
            dc <= 1'b0;
            x <= 0;
            y <= 0;
            R_byte <= 0;
        end
        else 
        if (index[9:4] != c_init_size) 
        begin
            index <= index + 1;
            if (index[3:0] == 4'h0)
            begin
                if (dc == 1'b0)
                    data <= c_spi_init[index[9:4]];
                else
                begin
                    if(c_color_bits < 12)
                      data <= color;
                    else
                    begin
                      R_byte <= ~R_byte;
                      if(R_byte == 1'b0)
                      begin
                        datalow <= color[7:0];
                        data <= color[15:8];
                      end
                      else
                        data <= datalow;
                    end
                    if(c_color_bits < 12 || R_byte == 1'b0)
                    begin
                      next_pixel <= 1'b1;
                      if (x == c_x_size-1)
                      begin
                        x <= 0;
                        y <= y + 1;
                      end
                      else
                        x <= x + 1;
                    end
                end
            end
            else
            begin
              next_pixel <= 1'b0;
              if (index[0] == 1'b0) 
                data[7:0] <= { data[6:0], 1'b0 };
            end
        end
        else // if (index[9:4] == c_init_size) 
        begin
            dc <= 1'b1;
            index[9:4] <= c_init_size - 1;
        end
      end
  end

  assign spi_resn = ~reset_cnt[0];
  assign spi_csn = reset_cnt[0]; 
  assign spi_dc = dc;
  assign spi_clk = ~index[0];
  assign spi_mosi = data[7];

endmodule
