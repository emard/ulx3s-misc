// SPI OLED SSD1331 display HEX decoder core
// AUTHOR=EMARD
// LICENSE=BSD

module oled_init
#(
  parameter C_dummy = 0
)
(
  input wire clk,
  
  output reg [7:0] debug,

  output wire oled_csn,
  output wire oled_clk,
  output wire oled_mosi,
  output wire oled_dc,
  output wire oled_resn
);
  localparam INIT_SIZE = 44; // bytes
  localparam FONT_SIZE = 136; // 5-bit words

  reg [7:0] oled_init[0:INIT_SIZE-1];
  reg [4:0] oled_font[0:FONT_SIZE-1]; // "0"-"F" and " "
  initial
  begin
    $readmemh("oled_init.mem", oled_init);
    $readmemb("oled_font.mem", oled_font);
  end

  reg [7:0] x;
  reg [5:0] y;
  wire [7:0] color;

  // assign color = x[2] ? 8'h1F : 8'h00;
  assign color = 8'h1E;

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
            x <= 8'd95;
            y <= 6'd0;
        end
        else if (init_cnt[9:4] != INIT_SIZE) 
        begin
            debug <= oled_init[1];
            init_cnt <= init_cnt + 1;
            if (init_cnt[3:0] == 4'b0000) 
            begin
                if (dc == 1'b0)
                begin
                    data <= oled_init[init_cnt[9:4]];
                end
                else
                begin
                    data <= color;
                    if (x == 0) begin
                        x <= 95; 
                        y <= y + 1;
                    end
                    else
                        x <= x - 1; 
                end
            end
            else if (init_cnt[0] == 1'b0) 
            begin
                data[7:0] <= { data[6:0], 1'b0 };
            end
        end
        else if (init_cnt[9:4] != INIT_SIZE) 
            init_cnt[9:4] <= INIT_SIZE - 1;

        if (init_cnt[9:4] == INIT_SIZE)
        begin
            dc <= 1'b1;
        end
  end

  assign oled_resn = ~reset_cnt[0];
  assign oled_csn = reset_cnt[0]; 
  assign oled_dc = dc;
  assign oled_clk = ~init_cnt[0];
  assign oled_mosi = data[7];

endmodule
