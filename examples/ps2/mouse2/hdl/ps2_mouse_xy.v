// ps2_mouse_xy gives a high-level interface to the mouse, which
// keeps track of the "absolute" x,y position (within a parameterized
// range) and also returns button presses.

module ps2_mouse_xy(clk, reset, ps2_clk, ps2_data, mx, my, btn_click);
   
   input clk, reset;
   inout ps2_clk, ps2_data;	// data to/from PS/2 mouse
   output [11:0] mx, my;  	// current mouse position, 12 bits
   output [2:0]  btn_click;	// button click: Left-Middle-Right
   
   // module parameters
   parameter 	 MAX_X = 1023;
   parameter 	 MAX_Y = 767;
   
   // low level mouse driver
   
   wire [8:0] 	 dx, dy;
   wire [2:0] 	 btn_click;
   wire 	 data_ready;
   wire 	 error_no_ack;
   wire [1:0] 	 ovf_xy;
   wire 	 streaming;
	
//   original 6.111 fall 2005 Verilog - appears to be buggy  so it has been 
//   commented out. 
//   ps2_mouse m1(clk,reset,ps2_clk,ps2_data,dx,dy,ovf_xy, btn_click,
//		data_ready,streaming);
//   	


// using ps2_mouse Verilog from Opencore  

// divide the clk by a factor of two sot that it works with 65mhz and the original timing
// parameters in the open core source.
// if the Verilog doesn't work the user should update the timing parameters. This  Verilog assumes
// 50MHz clock; seems to work with 32.5mhz without problems. GPH  11/23/2008 with 
// assist from BG

ps2_mouse_interface  
#(
   .WATCHDOG_TIMER_VALUE_PP(52000),
   .WATCHDOG_TIMER_BITS_PP(16),
   .DEBOUNCE_TIMER_VALUE_PP(246),
   .DEBOUNCE_TIMER_BITS_PP(8)) 
ps2_mouse_interface_inst
(
  .clk(clk),
  .reset(reset),
  .ps2_clk(ps2_clk),
  .ps2_data(ps2_data),
  .x_increment(dx),
  .y_increment(dy),
  .data_ready(data_ready),
  .read(1'b1),  // force a read 
  .left_button(btn_click[2]),
  .right_button(btn_click[0])  // rx_read_o  
);
  
   //  error_no_ack  not used


   // Update "absolute" position of mouse
   
   reg [11:0]  mx, my;
   wire        sx = dx[8];		// signs
   wire        sy = dy[8];		
   wire [8:0]  ndx = sx ? {0,~dx[7:0]}+1 : {0,dx[7:0]};	// magnitudes
   wire [8:0]  ndy = sy ? {0,~dy[7:0]}+1 : {0,dy[7:0]};
   
   always @(posedge clk) begin
      mx <= reset ? 0 :
	    data_ready ? (sx ? (mx>ndx ? mx - ndx : 0) 
			  : (mx < MAX_X - ndx ? mx+ndx : MAX_X)) : mx;
      // note Y is flipped for video cursor use of mouse
      my <= reset ? 0 :
	    data_ready ? (sy ? (my < MAX_Y - ndy ? my+ndy : MAX_Y)
			  : (my>ndy ? my - ndy : 0))  : my;
//	    data_ready ? (sy ? (my>ndy ? my - ndy : 0) 
//			  : (my < MAX_Y - ndy ? my+ndy : MAX_Y)) : my;
   end
   
endmodule

