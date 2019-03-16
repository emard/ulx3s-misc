// SPI OLED SSD1331 display video XY scan core
// AUTHORS=EMARD,MMICKO
// LICENSE=BSD

module oled_video
#(
  // file name is relative to directory path in which verilog compiler is running
  // screen can be also XY flipped and/or rotated from this init file
  parameter C_init_file = "oled_init.mem",
  parameter C_init_size = 44, // bytes in init file
  parameter C_x_size = 96,  // pixel X screen size (don't touch)
  parameter C_y_size = 64,  // pixel Y screen size (don't touch)
  parameter C_x_bits = 7,   // fits X screen size (don't touch)
  parameter C_y_bits = 6    // fits X screen size (don't touch)
)
(
  input  wire clk, // SPI display clock rate will be half of this clock rate
  
  output reg  [C_x_bits-1:0] x,
  output reg  [C_y_bits-1:0] y,
  input  wire [7:0] color, // color = f(x,y) {3'bRRR, 3'bGGG, 2'bBB }

  output wire oled_csn,
  output wire oled_clk,
  output wire oled_mosi,
  output wire oled_dc,
  output wire oled_resn
);

  reg [7:0] oled_init[0:C_init_size-1];
  initial
  begin
    $readmemh(C_init_file, oled_init);
  end

  reg [1:0] reset_cnt;
  reg [22:0] counter;
  reg [9:0] init_cnt;
  reg [7:0] data;
  reg dc;

  always @(posedge clk) begin
        counter <= counter + 1;
        if (reset_cnt != 2'b10) 
        begin
            reset_cnt <= reset_cnt+1;
            init_cnt <= 10'd0;
            data <= 8'd0;
            dc <= 1'b0;
            x <= 0;
            y <= 0;
        end
        else if (init_cnt[9:4] != C_init_size) 
        begin
            init_cnt <= init_cnt + 1;
            if (init_cnt[3:0] == 4'h0)
            begin
                if (dc == 1'b0)
                    data <= oled_init[init_cnt[9:4]];
                else
                begin
                    data <= color;
                    if (x == C_x_size-1)
                    begin
                        x <= 0;
                        y <= y + 1;
                    end
                    else
                        x <= x + 1;
                end
            end
            else if (init_cnt[0] == 1'b0) 
                data[7:0] <= { data[6:0], 1'b0 };
        end
        else if (init_cnt[9:4] == C_init_size) 
        begin
            init_cnt[9:4] <= C_init_size - 1;
            dc <= 1'b1;
        end
  end

  assign oled_resn = ~reset_cnt[0];
  assign oled_csn = reset_cnt[0]; 
  assign oled_dc = dc;
  assign oled_clk = ~init_cnt[0];
  assign oled_mosi = data[7];

endmodule
