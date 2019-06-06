module sdram_hex_oled
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,
    output wire oled_csn,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire oled_resn,

//  SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
    output sdram_csn,       // chip select
    output sdram_clk,       // clock to SDRAM
    output sdram_cke,       // clock enable to SDRAM	
    output sdram_rasn,      // SDRAM RAS
    output sdram_casn,      // SDRAM CAS
    output sdram_wen,       // SDRAM write-enable
    output [12:0] sdram_a,  // SDRAM address bus
    output [1:0] sdram_ba,  // SDRAM bank-address
    output [1:0] sdram_dqm, // byte select
    inout [15:0] sdram_d,   // data bus to/from SDRAM	

    output wire wifi_gpio0
);
    parameter C_color_bits = 16; // 8 or 16
    assign wifi_gpio0 = btn[0];

    wire [3:0] clk_out;
    clk_25_125_25_12_100
    clk_pll_inst
    ( 
      .clkin(clk_25mhz), // 25 MHz from onboard oscillator
      .clkout(clk_out), // 0:125 1:25 2:12.5 3:100 MHz
      .locked(locked)
    );
    
    wire clk_oled;
    assign clk_oled = clk_out[2]; // 12.5 MHz
    
    wire clk_sdram;
    assign clk_sdram = clk_out[1]; // 25 MHz
    wire [15:0] ram_out;
    
    reg [1:0] sys_cmd = 2'b00; // NOP
    reg [22:0] sys_addr = 23'h000000;
    reg [15:0] sys_din = 16'hABCD;
    wire [15:0] sys_dout;

    wire sys_rd_data_valid, sys_wr_data_valid;
    wire [1:0] sys_cmd_ack;
    sdram_16bit
    sdram_16bit_inst
    (
        .sys_CLK(clk_sdram),    // clock
        // CPU/system connection
        .sys_CMD(sys_cmd),      // 2'b00:nop, 2'b01:write 256 bytes, 2'b10:read 32 bytes, 2'b11:read 256 bytes
        .sys_ADDR(sys_addr),    // word address
        .sys_DIN(sys_din),      // data input
        .sys_DOUT(sys_dout),    // data output
        .sys_rd_data_valid(sys_rd_data_valid),	// data valid read
        .sys_wr_data_valid(sys_wr_data_valid),	// data valid write
        .sys_cmd_ack(sys_cmd_ack),		// command acknowledged
        // SDRAM chip connection
        .sdr_n_CS_WE_RAS_CAS({sdram_csn, sdram_wen, sdram_rasn, sdram_casn}), // #CS, #WE, #RAS, #CAS
        .sdr_BA(sdram_ba),      // SDRAM bank address
        .sdr_ADDR(sdram_a),	// SDRAM address
        .sdr_DATA(sdram_d),     // SDRAM data
        .sdr_DQM(sdram_dqm)	// SDRAM byte select
    );
    assign sdram_clk = ~clk_sdram; // phase shifted 180 deg
    assign sdram_cke = 1'b1;

    // RAM R/W state machine
    reg R_inc = 1'b0;
    reg [15:0] R_rd_data;
    reg [23:0] R_state_latch;
    reg [23:0] state;
    always @(posedge clk_sdram)
    begin
      if(state == 24'h110000)
      begin
        sys_cmd <= 2'b01; // write 256 bytes
        sys_addr <= 23'h000000;
      end
      if(sys_cmd == 2'b01 && sys_cmd_ack == 2'b01)
      begin
        // after ACK, remove CMD
        // R_state_latch <= state; // display at which state sys_wr_data_valid=1
        sys_cmd <= 2'b00; // NOP
      end
      if(sys_wr_data_valid)
      begin
        R_state_latch <= state; // display at which state sys_wr_data_valid=1
        R_inc <= 1'b1; // start incrementing
      end
      else
        R_inc <= 1'b0; // stop incrementing
      sys_din <= state[15:0];
      if(state == 24'h112000)
      begin
        sys_cmd <= 2'b10; // read 32 bytes
        sys_addr <= 23'h000000;
      end
      if(sys_cmd == 2'b10 && sys_cmd_ack == 2'b10) // && sys_rd_data_valid == 1'b1)
      begin
        // after ACK, remove CMD
        //R_state_latch <= state; // display at which state sys_rd_data_valid=1
        R_rd_data <= sys_dout;
        sys_cmd <= 2'b00; // NOP
      end
      state <= state + 1;
    end

    reg [127:0] R_display; // something to display
    always @(posedge clk_oled)
    begin
      R_display[63:48] <= sys_din;
      R_display[40:16] <= sys_addr;
      R_display[15:0] <= R_rd_data;
      R_display[125:124] <= sys_cmd;
      R_display[121:120] <= sys_cmd_ack;
      R_display[116] <= sys_wr_data_valid;
      R_display[112] <= sys_rd_data_valid;
      R_display[23+64:64] <= R_state_latch;
    end

    wire [6:0] x;
    wire [5:0] y;
    wire next_pixel;
    wire [C_color_bits-1:0] color;

    hex_decoder
    #(
        .C_data_len(128),
        .C_font_file("oled_font.mem"),
        .C_color_bits(C_color_bits)
    )
    hex_decoder_inst
    (
        .clk(clk_oled),
        .en(1'b1),
        .data(R_display),
        .x(x),
        .y(y),
        .next_pixel(next_pixel),
        .color(color)
    );
    
    oled_video
    #(
        .C_init_file("oled_init_xflip_16bit.mem"),
        .C_color_bits(C_color_bits)
    )
    oled_video_inst
    (
        .clk(clk_oled),
        .x(x),
        .y(y),
        .next_pixel(next_pixel),
        .color(color),
        .oled_csn(oled_csn),
        .oled_clk(oled_clk),
        .oled_mosi(oled_mosi),
        .oled_dc(oled_dc),
        .oled_resn(oled_resn)
    );

endmodule
