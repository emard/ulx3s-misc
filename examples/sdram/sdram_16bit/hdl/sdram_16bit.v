`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the Next186 Soc PC project
// http://opencores.org/project,next186
//
// Filename: sdram.v
// Description: Part of the Next186 SoC PC project, SDRAM controller
// Version 1.0
// Creation date: Feb2014
//
// Author: Nicolae Dumitrache 
// e-mail: ndumitrache@opencores.org
//
/////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (C) 2014 Nicolae Dumitrache
// 
// This source file may be used and distributed without 
// restriction provided that this copyright statement is not 
// removed from the file and that any derivative work contains 
// the original copyright notice and the associated disclaimer.
// 
// This source file is free software; you can redistribute it 
// and/or modify it under the terms of the GNU Lesser General 
// Public License as published by the Free Software Foundation;
// either version 2.1 of the License, or (at your option) any 
// later version. 
// 
// This source is distributed in the hope that it will be 
// useful, but WITHOUT ANY WARRANTY; without even the implied 
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
// PURPOSE. See the GNU Lesser General Public License for more 
// details. 
// 
// You should have received a copy of the GNU Lesser General 
// Public License along with this source; if not, download it 
// from http://www.opencores.org/lgpl.shtml 
//
// EMARD cleanup 2019
// 
///////////////////////////////////////////////////////////////////////////////////
// Additional Comments: 
//////////////////////////////////////////////////////////////////////////////////

module sdram_16bit
	#(
		parameter [7:0] C_RD1 = 8'h10,
		parameter [7:0] C_RD2 = 8'h80,
		parameter [7:0] C_WR2 = 8'h80,

		parameter C_PitchBits =  1,

		parameter C_ColBits   =  9, // column bits
		parameter C_RowBits   = 13, // row bits
		parameter C_BankBits  =  2, // bank bits

		parameter C_tRP       =  3,
		parameter C_tMRD      =  2,
		parameter C_tRCD      =  3,
		parameter C_tRC       =  9,
		parameter C_CL        =  3, // CAS latency
		parameter C_tREF      = 64, // ms

		parameter C_RFB	      = 11  // refresh bit = floor(log2(CLK*C_tREF/(2^RowBits)))
	)
	(
		input sys_CLK,						// clock
		input [1:0]sys_CMD,					// 00=nop, 01 = write WR2 bytes, 10=read RD1 bytes, 11=read RD2 bytes
		input [C_RowBits+C_BankBits+C_ColBits-C_PitchBits-1:0]sys_ADDR,			// word address, multiple of 2^PitchBits words
		input [15:0]sys_DIN,				// data input
		output reg [15:0]sys_DOUT,
		output reg sys_rd_data_valid = 0,	// data valid out
		output reg sys_wr_data_valid = 0,	// data valid in
		output reg [1:0]sys_cmd_ack = 0,	// command acknowledged
		
		output reg [3:0]sdr_n_CS_WE_RAS_CAS = 4'b1111,			// SDRAM #CS, #WE, #RAS, #CAS
		output reg [1:0]sdr_BA,				// SDRAM bank address
		output reg [12:0]sdr_ADDR,			// SDRAM address
		inout [15:0]sdr_DATA,				// SDRAM data
		output reg [1:0]sdr_DQM = 2'b11		// SDRAM DQM
	);

	reg [C_RowBits-1:0]actLine[3:0];
	reg [(1<<C_BankBits)-1:0]actBank = 0;
	reg [2:0]STATE = 0;
	reg [2:0]RET;		// return state
	reg [6:0]DLY;		// delay
	reg [15:0]counter = 0;	// refresh counter
	reg rfsh = 1;			// refresh bit
	reg [C_ColBits-C_PitchBits-1:0]colAddr;
	reg [C_BankBits-1:0]bAddr;
	reg [C_RowBits-1:0]linAddr;
	reg [15:0]reg_din;
	reg [2:0]out_data_valid = 0;
	
	assign sdr_DATA = out_data_valid[2] ? reg_din : 16'hzzzz;

	always @(posedge sys_CLK) begin
			counter <= counter + 1;
			sdr_n_CS_WE_RAS_CAS <= 4'b1xxx; // NOP
			STATE <= 1;
			reg_din <= sys_DIN;
			out_data_valid <= {out_data_valid[1:0], sys_wr_data_valid};
			DLY <= DLY - 1;
			sys_DOUT <= sdr_DATA;
			
			case(STATE)
				0: begin
					sys_rd_data_valid <= 1'b0;
					if(sdr_DQM[0]) STATE <= counter[15] ? 2 : 0;	// initialization, wait >200uS
					else begin	// wait new command
						if(rfsh != counter[C_RFB]) begin
							rfsh <= counter[C_RFB];
							STATE <= 2;	// precharge all
						end else if(|sys_CMD) begin
							sys_cmd_ack <= sys_CMD;
							{linAddr, bAddr, colAddr} <= sys_ADDR;
							STATE <= 5;
						end else STATE <= 0;
					end
				end
			
				1: begin
					if(DLY == 2) sys_wr_data_valid <= 1'b0;
					if(DLY == 0) STATE <= RET;	// NOP for DLY clocks, return to RET state
				 end

				2: begin	// precharge all
					sdr_n_CS_WE_RAS_CAS <= 4'b0001;
					sdr_ADDR[10] <= 1'b1;
					RET <= sdr_DQM[0] ? 3 : 4;
					DLY <= C_tRP - 2;
					actBank <= 0;
				end
					
				3: begin	// Mode Register Set
					sdr_n_CS_WE_RAS_CAS <= 4'b0000;
					sdr_ADDR <= 13'b00_0_0_00_000_0_111 + (C_CL<<4);	// burst read/burst write _ normal mode _ C_CL CAS latency _ sequential _ full page burst
					sdr_BA <= 2'b00;
					RET <= 4;
					DLY <= C_tMRD - 2;
				end
				
				4: begin // autorefresh
					sdr_n_CS_WE_RAS_CAS <= 4'b0100;
					if(rfsh != counter[C_RFB]) RET <= 4;
					else begin
						sdr_DQM <= 2'b00;
						RET <= 0;
					end
					DLY <= C_tRC - 2;
				end
				
				5: begin	// read/write
					sdr_BA <= bAddr;
					if(actBank[bAddr]) // bank active
						if(actLine[bAddr] == linAddr) begin // line already active
							sdr_ADDR[10] <= 1'b0; // no auto precharge
							sdr_ADDR[C_ColBits-1:0] <= {colAddr, {C_PitchBits{1'b0}}}; 
							RET <= 7;
							if(sys_cmd_ack[1]) begin	// read
								sdr_n_CS_WE_RAS_CAS <= 4'b0110; // read command
								DLY <= C_CL - 1;
							end else begin	// write
								DLY <= 1;
								sys_wr_data_valid <= 1'b1;
							end
						end else begin // bank precharge
							sdr_n_CS_WE_RAS_CAS <= 4'b0001;
							sdr_ADDR[10] <= 1'b0;
							actBank[bAddr] <= 1'b0;
							RET <= 5;
							DLY <= C_tRP - 2;								
						end
					else begin // bank activate
						sdr_n_CS_WE_RAS_CAS <= 4'b0101;
						sdr_ADDR[C_RowBits-1:0] <= linAddr;
						actBank[bAddr] <= 1'b1;
						actLine[bAddr] <= linAddr;
						RET <= 5;
						DLY <= C_tRCD - 2;
					end
				end 
				
				6: begin	// end read/write phase
					sys_cmd_ack <= 2'b00;
					sdr_n_CS_WE_RAS_CAS <= 4'b0011;	// burst stop
					STATE <= sys_cmd_ack[1] ? 1 : 0; // read write
					RET <= 0;
					DLY <= 2;
				end
				
				7: begin	// init read/write phase
					if(sys_cmd_ack[1]) sys_rd_data_valid <= 1'b1;
					else sdr_n_CS_WE_RAS_CAS <= 4'b0010;	// write command
					RET <= 6;
					DLY <= sys_cmd_ack[1] ? sys_cmd_ack[0] ? C_RD2 - 6 : C_RD1 - 6 : C_WR2 - 2;
				end
				
			endcase
	end
	
endmodule
