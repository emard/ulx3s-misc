// SPI OLED SSD1331 display video XY scan core
// AUTHORS=EMARD,MMICKO
// LICENSE=BSD

module oled_video
#(
  // file name is relative to directory path in which verilog compiler is running
  // screen can be also XY flipped and/or rotated from this init file
  parameter C_init_file = "oled_init.mem",
  parameter C_init_size = 44, // bytes in init file
  parameter C_color_bits = 8, // 8 or 16 color depth (should match init file)
  parameter C_x_size = 96,  // pixel X screen size (don't touch)
  parameter C_y_size = 64,  // pixel Y screen size (don't touch)
  parameter C_x_bits = 7,   // fits X screen size (don't touch)
  parameter C_y_bits = 6    // fits X screen size (don't touch)
)
(
  input  wire clk, // SPI display clock rate will be half of this clock rate
  
  output reg  [C_x_bits-1:0] x,
  output reg  [C_y_bits-1:0] y,
  output reg  next_pixel, // 1 when x/y changes
  input  wire [C_color_bits-1:0] color, // color = f(x,y) {3'bRRR, 3'bGGG, 2'bBB }

  output wire oled_csn,
  output wire oled_clk,
  output wire oled_mosi,
  output wire oled_dc,
  output wire oled_resn
);

  // "wire" should be used instead of "reg" because it's ROM.
  // trellis works with either "wire" or "reg"
  // diamond works only with "reg"
  reg [7:0] C_oled_init[0:C_init_size-1];
  initial
  begin
    $readmemh(C_init_file, C_oled_init);
  end

  reg [1:0] reset_cnt;
  reg [9:0] init_cnt;
  reg [7:0] data;
  reg dc;

  reg byte; // alternates data byte for 16-bit mode
  wire [7:0] color_to_data;
  generate
    if(C_color_bits < 12)
      assign color_to_data = color;
    else
      assign color_to_data = byte ? color[15:8] : color[7:0];
  endgenerate
  reg [7:0] datalow; // LSB byte of 16-bit data transfer

  always @(posedge clk) begin
        if (reset_cnt != 2'b10) 
        begin
            reset_cnt <= reset_cnt+1;
            init_cnt <= 10'd0;
            data <= C_oled_init[0];
            dc <= 1'b0;
            x <= 0;
            y <= 0;
            byte <= 0;
        end
        else 
        if (init_cnt[9:4] != C_init_size) 
        begin
            init_cnt <= init_cnt + 1;
            if (init_cnt[3:0] == 4'h0)
            begin
                if (dc == 1'b0)
                    data <= C_oled_init[init_cnt[9:4]];
                else
                begin
                    if(C_color_bits < 12)
                      data <= color;
                    else
                    begin
                      byte <= ~byte;
                      if(byte == 1'b0)
                      begin
                        datalow <= color[7:0];
                        data <= color[15:8];
                      end
                      else
                        data <= datalow;
                    end
                    if(C_color_bits < 12 || byte == 1'b0)
                    begin
                      next_pixel <= 1'b1;
                      if (x == C_x_size-1)
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
              if (init_cnt[0] == 1'b0) 
                data[7:0] <= { data[6:0], 1'b0 };
            end
        end
        else // if (init_cnt[9:4] == C_init_size) 
        begin
            dc <= 1'b1;
            init_cnt[9:4] <= C_init_size - 1;
        end
  end

  assign oled_resn = ~reset_cnt[0];
  assign oled_csn = reset_cnt[0]; 
  assign oled_dc = dc;
  assign oled_clk = ~init_cnt[0];
  assign oled_mosi = data[7];

endmodule
