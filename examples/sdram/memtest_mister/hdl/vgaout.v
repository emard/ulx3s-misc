// input clock: 14MHz
// output format: 31460 x 70 Hz (like 720x400@70)

module vgaout
(
	input clk,

	input [31:0] rez1,
	input [31:0] rez2,

	input [15:0] freq,
	input [15:0] elapsed,
	input  [7:0] mark,

	output reg hs,
	output reg vs,
	output reg de,
	output reg [1:0] b,
	output reg [1:0] r,
	output reg [1:0] g
);

localparam HSYNC_BEG   = 12'd0;
localparam HSYNC_END   = 12'd62;
localparam HSCRN_BEG   = 12'd128;
localparam HREZ        = 12'd240;
localparam HSCRN_END   = 12'd848;
localparam HMAX        = 12'd858;

localparam VSYNC_BEG   = 12'd0;
localparam VSYNC_END   = 12'd6;
localparam VSCRN_BEG   = 12'd30;
localparam VREZ4       = 12'd96;
localparam VREZ3       = 12'd112;
localparam VREZ1       = 12'd240;
localparam VREZ2       = 12'd368;
localparam VSCRN_END   = 12'd510;
localparam VMAX        = 12'd525;

reg [11:0] hcount, vcount;
reg hscr, vscr, nextline;
reg [31:0] r1, r2, r3;
reg [7:0] r4;

reg [5:0] xr;
reg [3:0] yr;

wire [3:0] rn;
wire rezpix;

assign rn = (vcount>=VREZ2) ? r2[31:28] : (vcount>=VREZ1) ? r1[31:28] : r3[31:28];

wire pix = (vcount<VREZ3) ? mpix : rezpix;
wire [5:0] pixcolor = (vcount>=VREZ2) ? 6'b001100 : (vcount>=VREZ1) ? 6'b110000 : (vcount>=VREZ3) ? 6'b111100 : 6'b110011;

hexnum digs
(
	.value(rn),
	.x({xr[2],xr[1]|xr[0]}),
	.y({yr[3:2],yr[1]|yr[0]}),
	.hide(vcount<VREZ1 && xr[5:3]==4),

	.image(rezpix)
);

wire mpix = ({xr[2],xr[1]|xr[0]} <= 2) && ((vcount>>3) == (VREZ4>>3)) && r4[7];

always @(posedge clk) begin

	if (hcount==HMAX) hcount <= 9'd0;
		else hcount <= hcount + 9'd1;

	if (hcount==HSCRN_END) begin
		hscr <= 1'b0;
		de <= 0;
	end else if (hcount==HSCRN_BEG) begin
		hscr <= 1'b1;
		de <= vscr;
	end

	if (hcount==HSYNC_BEG) begin
		nextline <= 1'b1;
		hs <= 1'b0;                  // negative H-sync
	end
	else
	begin
		nextline <= 1'b0;
		if (hcount==HSYNC_END)
			hs <= 1'b1;
	end

	if (hcount==HREZ) begin
		xr <= 6'd0;
		r1 <= rez1;
		r2 <= rez2;
		r3 <= {elapsed, freq};
		r4 <= mark;
	end
	else if ( (!hcount[2:0]) && (xr!=6'h3f) ) begin
		xr <= xr + 6'd1;
		if (xr[2:0]==3'd7) begin
			r1[31:4] <= r1[27:0];
			r2[31:4] <= r2[27:0];
			r3[31:4] <= r3[27:0];
			r4[7:1]  <= r4[6:0];
		end
	end

	if (nextline) begin
		if (vcount==VMAX)
			vcount <= 9'd0;
		else
			vcount <= vcount + 9'd1;

		if (vcount==VSCRN_END)
			vscr <= 1'b0;
		else if (vcount==VSCRN_BEG)
			vscr <= 1'b1;

		if (vcount==VSYNC_BEG)
			vs <= 1'b1;                 // positive V-sync
		else if (vcount==VSYNC_END)
			vs <= 1'b0;

		if ( (vcount==VREZ1) || (vcount==VREZ2) || (vcount==VREZ3))
			yr <= 4'd0;
		else if ( (vcount[2:0]==3'b000) && (yr!=4'hf) )
			yr <= yr + 4'd1;

	end

	{g,r,b} <= pix ? pixcolor : (hscr&vscr) ? 6'b000001 : 6'b000000;

end

endmodule

//=============================================================================

module hexnum
(
	input  [3:0] value,
	input  [1:0] x,
	input  [2:0] y,
	input        hide,

	output image
);

reg [6:0] ss;
reg i;

always @(*) begin
	if(hide) ss <= 7'b0000000;
	else
	case (value)  //gfedcba
	4'h0: ss <= 7'b0111111;
	4'h1: ss <= 7'b0000110;
	4'h2: ss <= 7'b1011011;
	4'h3: ss <= 7'b1001111;
	4'h4: ss <= 7'b1100110;
	4'h5: ss <= 7'b1101101;
	4'h6: ss <= 7'b1111101;
	4'h7: ss <= 7'b0000111;
	4'h8: ss <= 7'b1111111;
	4'h9: ss <= 7'b1101111;
	4'ha: ss <= 7'b1110111;
	4'hb: ss <= 7'b1111100;
	4'hc: ss <= 7'b0111001;
	4'hd: ss <= 7'b1011110;
	4'he: ss <= 7'b1111001;
	4'hf: ss <= 7'b1110001;
	endcase
end

always @(*) begin
	case (y)
	3'd0: case (x)
				3'd0: i <= ss[0]|ss[5];
				3'd1: i <= ss[0];
				3'd2: i <= ss[0]|ss[1];
				default: i <= 1'b0;
			endcase
	3'd1: case (x)
				3'd0: i <= ss[5];
				3'd2: i <= ss[1];
				default: i <= 1'b0;
			endcase
	3'd2: case (x)
				3'd0: i <= ss[5]|ss[4];//|ss[6];
				3'd1: i <= ss[6];
				3'd2: i <= ss[1]|ss[2];//|ss[6];
				default: i <= 1'b0;
			endcase
	3'd3: case (x)
				3'd0: i <= ss[4];
				3'd2: i <= ss[2];
				default: i <= 1'b0;
			endcase
	3'd4: case (x)
				3'd0: i <= ss[3]|ss[4];
				3'd1: i <= ss[3];
				3'd2: i <= ss[3]|ss[2];
				default: i <= 1'b0;
			endcase
	default: i <= 1'b0;
	endcase
end

assign image = i;

endmodule
