// intercept video stream and make a window

module osd
#(
  parameter C_x_start = 120,
  parameter C_x_stop  = 360,
  parameter C_y_start = 120,
  parameter C_y_stop  = 360
)
(
  input  wire clk_pixel, clk_pixel_ena,
  input  wire [7:0] i_r,
  input  wire [7:0] i_g,
  input  wire [7:0] i_b,
  input  wire i_hsync, i_vsync, i_blank,
  output wire [7:0] o_r,
  output wire [7:0] o_g,
  output wire [7:0] o_b,
  output wire o_hsync, o_vsync, o_blank
);


  reg osd_en, osd_xen, osd_yen;
  reg xcount_en, ycount_en;
  reg R_hsync_prev;
  reg [10:0] xcount, ycount;
  always @(posedge clk_pixel)
  begin
    if(clk_pixel_ena)
    begin
      if(i_vsync)
      begin
        ycount <= 0;
        ycount_en <= 0; // wait for blank before counting
      end
      else
      begin
        if(i_blank == 1'b0) // display unblanked
          ycount_en <= 1'b1;
        if(R_hsync_prev == 1'b0 && i_hsync == 1'b1)
        begin // hsync rising edge
          xcount <= 0;
          xcount_en <= 0;
          if(ycount_en)
            ycount <= ycount + 1;
          if(ycount == C_y_start)
            osd_yen <= 1;
          if(ycount == C_y_stop)
            osd_yen <= 0;
        end
        else
        begin
          if(i_blank == 1'b0) // display unblanked
            xcount_en <= 1'b1;
          if(xcount_en)
            xcount <= xcount + 1;
          if(xcount == C_x_start)
            osd_xen <= 1;
          if(xcount == C_x_stop)
            osd_xen <= 0;
        end
        R_hsync_prev <= i_hsync;
      end
      osd_en <= osd_xen & osd_yen;
    end
  end

  reg [7:0] R_vga_r, R_vga_g, R_vga_b;
  reg R_hsync, R_vsync, R_blank;
  always @(posedge clk_pixel)
  begin
    if(clk_pixel_ena)
    begin
      R_vga_r <= i_r;
      R_vga_g <= i_g;
      if(osd_en)
        R_vga_b <= 8'hFF;
      else
        R_vga_b <= i_b;
      R_hsync <= i_hsync;
      R_vsync <= i_vsync;
      R_blank <= i_blank;
    end
  end
  
  assign o_r = R_vga_r;
  assign o_g = R_vga_g;
  assign o_b = R_vga_b;
  assign o_hsync = R_hsync;
  assign o_vsync = R_vsync;
  assign o_blank = R_blank;

endmodule
