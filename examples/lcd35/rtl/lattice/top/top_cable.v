// 3.5" LCD PMOD connected over 40-pin IDE flat cable
// to onboard male upright header
// GP,GN 14-17,21-24
// note: flat cable swaps GP and GN

module top
(
    input clk_25mhz,
    output wifi_gpio0,
    output [7:0] led,
    output [27:0] gp,gn
);

// keeps board running
assign wifi_gpio0 = 1'b1;

/* ------------------------
       Clock generator 
   ------------------------*/

wire locked;
wire pixclk;

clk_25m_287m5_19m17 pll_i
(
  .CLKI(clk_25mhz), // 25 MHz from onboard oscillator
//.CLKOP(shiftclk), // 287.5 MHz (unused)
  .CLKOS(pixclk), // 19.1667 MHz pixel clock for LCD
  .LOCKED(locked)
);

// small blinky
reg [23:0] R_blinky;
always @(posedge pixclk)
begin
  R_blinky <= R_blinky+1;
end

assign led[0] = R_blinky[23];

wire [23:0] rgb_data;
wire [9:0] h_pos;
wire [9:0] v_pos;

// red color full screen
// assign rgb_data = 24'hff0000;
// some rainbow example
assign rgb_data = (h_pos < 64)  ? {h_pos[5:0], 18'd0} :
                  (h_pos < 128) ? {8'd0, h_pos[5:0], 10'd0} :
                  (h_pos < 192) ? {16'd0, h_pos[5:0], 2'd0} :
                  (h_pos < 256) ? {h_pos[5:0], 2'd0, h_pos[5:0], 2'd0, h_pos[5:0], 2'd0} :
                  (h_pos < 320) ? {h_pos[5:0], 2'd0, 8'd0, h_pos[5:0], 2'd0} :
                  24'd0;

wire lcd_spena, lcd_resetn, lcd_spdat, lcd_spclk, lcd_vsync, lcd_hsync, lcd_dclk, lcd_den;
wire [7:0] lcd_dat;

video generator
(
  .clk(pixclk), // pixel clock in
  .resetn(locked),
  .lcd_dat(lcd_dat), // 8-bit
  .lcd_hsync(lcd_hsync),
  .lcd_vsync(lcd_vsync),
  .lcd_den(lcd_den),
  .h_pos(h_pos),
  .v_pos(v_pos),
  .rgb_data(rgb_data)
);

assign lcd_dclk = pixclk;
assign lcd_spclk = 1'b1;
assign lcd_spdat = 1'b1;
assign lcd_resetn = 1'b1;
assign lcd_spena = 1'b1;

// board pins to display pins
assign gn[24] = lcd_den;
assign gp[24] = lcd_dclk;
assign gn[23] = lcd_hsync;
assign gp[23] = lcd_vsync;
//assign gp[22] = lcd_spclk;
//assign gn[22] = lcd_spdat;
assign gn[21] = lcd_resetn;
//assign gn[21] = lcd_spena;

assign gn[17] = lcd_dat[7];
assign gp[17] = lcd_dat[6];
assign gn[16] = lcd_dat[5];
assign gp[16] = lcd_dat[4];
assign gn[15] = lcd_dat[3];
assign gp[15] = lcd_dat[2];
assign gn[14] = lcd_dat[1];
assign gp[14] = lcd_dat[0];

endmodule
