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

    wire clk, locked;
    pll
    pll_inst
    (
        .clki(clk_25mhz),
        .clko(clk), // 12.5 MHz
        .locked(locked)
    );
    
    wire clk_sdr;
    assign clk_sdr = clk_25mhz;
    wire [15:0] ram_out;

    sdram_16bit
    sdram_16bit_inst
    (
        .sys_CLK(clk_sdr),      // clock
        .sys_CMD(2'b00),	// 00=nop, 01 = write 256 bytes, 10=read 32 bytes, 11=read 256 bytes
        .sys_ADDR(25'h000000),	// word address
        .sys_DIN(16'hABCD),	// data input
        .sys_DOUT(ram_out),					// data output
        //.sys_rd_data_valid(sys_rd_data_valid),	// data valid read
        //.sys_wr_data_valid(sys_wr_data_valid),	// data valid write
        //.sys_cmd_ack(sys_cmd_ack),			// command acknowledged
		
        .sdr_n_CS_WE_RAS_CAS({sdram_csn, sdram_wen, sdram_rasn, sdram_casn}), // SDRAM #CS, #WE, #RAS, #CAS
        .sdr_BA(sdram_ba),					// SDRAM bank address
        .sdr_ADDR(sdram_a),				// SDRAM address
        .sdr_DATA(sdram_dq),				// SDRAM data
        .sdr_DQM(sdram_dqm)					// SDRAM DQM
    );

    reg [127:0] R_display; // something to display
    always @(posedge clk)
    begin
      R_display[0] <= btn[0];
      R_display[4] <= btn[1];
      R_display[8] <= btn[2];
      R_display[12] <= btn[3];
      R_display[16] <= btn[4];
      R_display[20] <= btn[5];
      R_display[24] <= btn[6];
      R_display[127:64] <= R_display[127:64] + 1; // shown in next OLED row
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
        .clk(clk),
        .en(1'b1),
        .data(R_display),
        .x(x),
        .y(y),
        .next_pixel(next_pixel),
        .color(color)
    );
    
    generate
      if(C_color_bits < 12)
        localparam C_init_file = "oled_init_xflip.mem";
      else
        localparam C_init_file = "oled_init_xflip_16bit.mem";
    endgenerate

    oled_video
    #(
        .C_init_file(C_init_file),
        .C_color_bits(C_color_bits)
    )
    oled_video_inst
    (
        .clk(clk),
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
