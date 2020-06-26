// PRESS BTN6-RIGHT to increase SDRAM chip phase shift
// PRESS BTN5-LEFT  to decrease SDRAM chip phase shift

// go up and down with BTNs and check that
// default phase shift is approx in the middle of the
// working range where errors don't appear

// counter on screen will increase immediately when BTN is pressed
// phase shift will be applied when BTN is released

module top_memtest
(
    input         clk_25mhz,
    input   [6:0] btn,
    output  [7:0] led,
    output  [3:0] gpdi_dp, gpdi_dn,
    //  SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
    output        sdram_csn,  // chip select
    output        sdram_clk,  // clock to SDRAM
    output        sdram_cke,  // clock enable to SDRAM	
    output        sdram_rasn, // SDRAM RAS
    output        sdram_casn, // SDRAM CAS
    output        sdram_wen,  // SDRAM write-enable
    output [12:0] sdram_a,    // SDRAM address bus
    output  [1:0] sdram_ba,   // SDRAM bank-address
    output  [1:0] sdram_dqm,  // byte select
    inout  [15:0] sdram_d,    // data bus to/from SDRAM	
    output        wifi_gpio0
);
    parameter C_ddr = 1'b1; // 0:SDR 1:DDR
    parameter C_clk_pixel_Hz  =  27500000; // Hz
    parameter C_clk_gui_Hz    =  50000000; // Hz
    parameter C_clk_sdram_Hz  = 112500000; // Hz
    parameter C_sdram_clk_deg =       120; // deg phase shift for chip
    parameter C_size_MB = 32; // 8/16/32/64 MB

    localparam [31:0] C_sec_max = C_clk_gui_Hz - 1;
    localparam [31:0] C_min_max = C_clk_gui_Hz*60 - 1;

    localparam [15:0] C_clk_sdram_1MHz = C_clk_sdram_Hz / 1000000;
    localparam [15:0] C_clk_sdram_10MHz = C_clk_sdram_1MHz / 10;
    localparam [15:0] C_clk_sdram_100MHz = C_clk_sdram_10MHz / 10;
    localparam [11:0] C_clk_sdram_bcd = (C_clk_sdram_100MHz % 10) * 'h100
                                      + (C_clk_sdram_10MHz  % 10) * 'h10
                                      + (C_clk_sdram_1MHz   % 10);

    // wifi_gpio0=1 keeps board from rebooting
    // hold btn0 to let ESP32 take control over the board
    assign wifi_gpio0 = btn[0];

    // clock generator for video and sys
    wire clk_video_locked;
    wire [3:0] clocks;
    ecp5pll
    #(
        .in_hz(25*1000000), // 25 MHz
      .out0_hz(C_ddr ? C_clk_pixel_Hz*5 : C_clk_pixel_Hz*10),
      .out1_hz(C_clk_pixel_Hz),
      .out2_hz(C_clk_gui_Hz)
    )
    clk_25_video
    (
      .clk_i(clk_25mhz),
      .clk_o(clocks),
      .locked(clk_video_locked)
    );
    wire clk_shift = clocks[0];
    wire clk_pixel = clocks[1];
    wire clk_sys   = clocks[2];
    wire clk_gui   = clk_pixel;

    localparam C_debounce_bits = 16;
    reg [C_debounce_bits-1:0] R_debounce;
    reg  [6:0] R_btn, R_btn_prev;
    reg        R_phasedir, R_phasestep, R_phasestep_early;
    reg        R_new;
    always @(posedge clk_gui)
    begin
      if(R_debounce[C_debounce_bits-1])
      begin
        if(R_btn != R_btn_prev)
        begin
          R_debounce <= 0;
          R_new <= 1;
        end
        R_btn <= btn;
        R_btn_prev <= R_btn;
      end
      else
      begin
        R_debounce <= R_debounce + 1;
        R_new <= 0;
      end
    end

    always @(posedge clk_gui)
    begin
      if(R_new)
      begin
        R_phasedir        <= R_btn[5] | R_btn[6] ? R_btn[6] : R_phasedir;
        R_phasestep_early <= R_btn[5] | R_btn[6];
      end
      // phasedir must be stable 5ns before phasestep is pulsed
      R_phasestep <= R_phasestep_early;
    end
    
    reg [11:0] R_phase_bcd;
    reg  [7:0] R_phase;
    always @(posedge clk_gui)
    begin
      if(R_phasestep_early == 1 && R_phasestep == 0)
        R_phase <= R_phasedir ? R_phase + 1 : R_phase - 1;
      R_phase_bcd <= R_phase;
    end

    wire clk_sdram;
    wire clk_sdram_locked;
    wire [3:0] clocks_sdram;
    ecp5pll
    #(
        .in_hz(25*1000000), // 25 MHz
      .out0_hz(C_clk_sdram_Hz),
      .out1_hz(C_clk_sdram_Hz), .out1_deg(C_sdram_clk_deg),
      .dynamic_en(1)
    )
    clk_25_sdram
    (
      .clk_i(clk_25mhz),
      .clk_o(clocks_sdram),
      .phasesel(2'd1), // select out1
      .phasedir(R_phasedir),
      .phasestep(R_phasestep),
      .phaseloadreg(0),
      .locked(clk_sdram_locked)
    );
    wire   clk_sdram = clocks_sdram[0];
    assign sdram_clk = clocks_sdram[1]; // phase shifted for the chip

    // LED blinky
    localparam counter_width = 28;
    wire [7:0] countblink;
    blink
    #(
      .bits(counter_width)
    )
    blink_instance
    (
      .clk(clk_gui),
      .led(countblink)
    );
//    assign led[0] = btn[1];
//    assign led[7:1] = countblink[7:1];

///////////////////////////////////////////////////////////////////

///// mister board specific keyboard control
/*
    reg recfg = 0;
    reg pll_reset = 0;

    reg [10:0] ps2_key;
    wire        mgmt_waitrequest;
    reg         mgmt_write;
    reg  [5:0]  mgmt_address;
    reg  [31:0] mgmt_writedata;
    wire [63:0] reconfig_to_pll;
    wire [63:0] reconfig_from_pll;

    wire [31:0] cfg_param[44];

    reg   [3:0] pos  = 0;
    reg         auto = 0;
    reg         ph_shift = 0;
    reg  [31:0] pre_phase;

    reg  [7:0] state = 0;
    reg        old_wait;
    reg [31:0] phase;
    reg        old_stb = 0;
    reg        shift = 0;

    always @(posedge clk_gui)
    begin

	mgmt_write <= 0;

	if(((locked && !mgmt_waitrequest) || pll_reset) && recfg) begin
		state <= state + 1'd1;
		if(!state[2:0]) begin
			case(state[7:3])
				// Start
				0: begin
						mgmt_address   <= 0;
						mgmt_writedata <= 0;
						mgmt_write     <= 1;
						if(!ph_shift)  pre_phase <= cfg_param[{pos, 2'd3}];
					end

				// M
				1: begin
						mgmt_address   <= 4;
						mgmt_writedata <= cfg_param[{pos, 2'd0}];
						mgmt_write     <= 1;
					end

				// K
				2: begin
						mgmt_address   <= 7;
						mgmt_writedata <= cfg_param[{pos, 2'd1}];
						mgmt_write     <= 1;
					end

				// N
				3: begin
						mgmt_address   <= 3;
						mgmt_writedata <= 'h10000;
						mgmt_write     <= 1;
					end

				// C0
				4: begin
						mgmt_address   <= 5;
						mgmt_writedata <= cfg_param[{pos, 2'd2}];
						mgmt_write     <= 1;
					end

				// C1
				5: begin
						mgmt_address   <= 5;
						mgmt_writedata <= cfg_param[{pos, 2'd2}] | 'h40000;
						mgmt_write     <= 1;
					end

				// Charge pump
				6: begin
						mgmt_address   <= 9;
						mgmt_writedata <= 1;
						mgmt_write     <= 1;
					end

				// Bandwidth
				7: begin
						mgmt_address   <= 8;
						mgmt_writedata <= 7;
						mgmt_write     <= 1;
					end

				// Apply
				8: begin
						mgmt_address   <= 2;
						mgmt_writedata <= 0;
						mgmt_write     <= 1;
					end

				9:  pll_reset <= 1;
				10: pll_reset <= 0;

				// Start
				11: begin
						mgmt_address   <= 0;
						mgmt_writedata <= 0;
						mgmt_write     <= 1;
						
						if(pre_phase > cfg_param[3]) phase <= pre_phase - cfg_param[3];
						else
						if(pre_phase < cfg_param[3]) phase <= (cfg_param[3] - pre_phase) | 'h200000;
						else
						begin
							// no change. finish.
							mgmt_write  <= 0;
							recfg <= 0;
						end
					end

				// Phase
				12: begin
						mgmt_address   <= 6;
						mgmt_writedata <= phase | 'h10000;
						mgmt_write     <= 1;
					end

				// Apply
				13: begin
						mgmt_address   <= 2;
						mgmt_writedata <= 0;
						mgmt_write     <= 1;
					end

				14: recfg <= 0;
			endcase
		end
	end

	old_stb <= ps2_key[10];
	if(old_stb != ps2_key[10]) begin
		state <= 0;
		if(ps2_key[9]) begin
			if(ps2_key[7:0] == 'h75 && pos > 0) begin
				recfg <= 1;
				pos <= pos - 1'd1;
				auto <= 0;
				ph_shift <= 0;
			end
			if(ps2_key[7:0] == 'h72 && pos < 10) begin
				recfg <= 1;
				pos <= pos + 1'd1;
				auto <= 0;
				ph_shift <= 0;
			end
			if(ps2_key[7:0] == 'h5a) begin
				recfg <= 1;
				auto <= 0;
				ph_shift <= shift;
			end
			if(ps2_key[7:0] == 'h1c) begin
				recfg <= 1;
				pos <= 0;
				auto <= 1;
				ph_shift <= 0;
			end
			if(ps2_key[7:0] == 'h74 && shift && pre_phase < 100) begin
				recfg <= 1;
				pre_phase <= pre_phase + 1'd1;
				auto <= 0;
				ph_shift <= 1;
			end
			if(ps2_key[7:0] == 'h6B && shift && pre_phase > 0) begin
				recfg <= 1;
				pre_phase <= pre_phase - 1'd1;
				auto <= 0;
				ph_shift <= 1;
			end
		end

		if(ps2_key[7:0] == 'h12) shift <= ps2_key[9];
	end

	if(auto && failcount && !recfg && pos < 10) begin
		recfg <= 1;
		pos <= pos + 1'd1;
		ph_shift <= 0;
	end
    end
*/
///////////////////////////////////////////////////////////////////

    reg timer_reset;
    always @(posedge clk_gui) // FIXME should we use hardware 25 MHz here?
        timer_reset <= ~(btn[0] & clk_video_locked);

    reg [15:0] mins;
    reg [31:0] min;
    always @(posedge clk_gui)
    begin
	if(timer_reset) begin
		min <= 0;
		mins <= 0;
	end else begin
		if(min == C_min_max) begin
			min <= 0;
			if(mins[3:0]<9) mins[3:0] <= mins[3:0] + 1'd1;
			else begin
				mins[3:0] <= 0;
				if(mins[7:4]<9) mins[7:4] <= mins[7:4] + 1'd1;
				else begin
					mins[7:4] <= 0;
					if(mins[11:8]<9) mins[11:8] <= mins[11:8] + 1'd1;
					else begin
						mins[11:8] <= 0;
						if(mins[15:12]<9) mins[15:12] <= mins[15:12] + 1'd1;
						else mins[15:12] <= 0;
					end
				end
			end
		end
		else
			min <= min + 1;
	end
    end

    reg [15:0] secs;
    reg [31:0] sec;
    always @(posedge clk_gui)
    begin
	if(timer_reset) begin
		sec <= 0;
		secs <= 0;
	end else begin
		if(sec == C_sec_max) begin
			sec <= 0;
			secs <= secs + 1;
		end
		else
			sec <= sec + 1;
	end
    end

///////////////////////////////////////////////////////////////////

    wire [31:0] passcount, failcount;

    reg resetn;
    always @(posedge clk_sdram) // FIXME should we use hardware 25 MHz here?
        resetn <= btn[0] & clk_sdram_locked;

    defparam my_memtst.DRAM_COL_SIZE = C_size_MB == 64 ? 10 : C_size_MB == 32 ? 9 : 8; // 8:8-16MB 9:32MB 10:64MB
    defparam my_memtst.DRAM_ROW_SIZE = C_size_MB > 8 ? 13 : 12; // 12:8MB 13:>=16MB
    mem_tester my_memtst
    (
	.clk(clk_sdram),
	.rst_n(resetn),
	.passcount(passcount),
	.failcount(failcount),
	.DRAM_DQ(sdram_d),
	.DRAM_ADDR(sdram_a),
	.DRAM_LDQM(sdram_dqm[0]),
	.DRAM_UDQM(sdram_dqm[1]),
	.DRAM_WE_N(sdram_wen),
	.DRAM_CS_N(sdram_csn),
	.DRAM_RAS_N(sdram_rasn),
	.DRAM_CAS_N(sdram_casn),
	.DRAM_BA_0(sdram_ba[0]),
	.DRAM_BA_1(sdram_ba[1])
    );
    assign sdram_cke = 1'b1;

    // most important info is failcond - lower 8 bits shown on LEDs
    assign led = failcount[7:0];

    // VGA signal generator
    wire VGA_DE;
    wire [1:0] vga_r, vga_g, vga_b;
    vgaout showrez
    (
        .clk(clk_pixel),
        .rez1(passcount),
        .rez2(failcount),
        // disabled to shorten compile time
//        .mark(8'h80 >> secs[2:0]),
//        .elapsed(mins),
//        .freq(C_clk_sdram_bcd),
        .freq(R_phase_bcd),
        .hs(vga_hsync),
        .vs(vga_vsync),
        .de(VGA_DE),
        .r(vga_r),
        .g(vga_g),
        .b(vga_b)
    );
    assign vga_blank = ~VGA_DE;

    // VGA to digital video converter
    wire [1:0] tmds[3:0];
    vga2dvid
    #(
      .C_depth(2),
      .C_ddr(C_ddr)
    )
    vga2dvid_instance
    (
      .clk_pixel(clk_pixel),
      .clk_shift(clk_shift),
      .in_red(vga_r),
      .in_green(vga_g),
      .in_blue(vga_b),
      .in_hsync(~vga_hsync),
      .in_vsync(~vga_vsync),
      .in_blank(vga_blank),
      .out_clock(tmds[3]),
      .out_red(tmds[2]),
      .out_green(tmds[1]),
      .out_blue(tmds[0])
    );
    
    // output TMDS SDR/DDR data to fake differential lanes
    fake_differential
    #(
      .C_ddr(C_ddr)
    )
    fake_differential_instance
    (
      .clk_shift(clk_shift),
      .in_clock(tmds[3]),
      .in_red(tmds[2]),
      .in_green(tmds[1]),
      .in_blue(tmds[0]),
      .out_p(gpdi_dp),
      .out_n(gpdi_dn)
    );

endmodule
