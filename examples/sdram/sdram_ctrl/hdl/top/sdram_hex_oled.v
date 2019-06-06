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
    parameter C_color_bits = 16; // 8 or 16 bit color display
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
    assign clk_sdram = clk_out[3]; // 100 MHz
    wire [15:0] ram_out;

    reg R_write_request = 1'b0;
    wire S_write_grant;
    reg [19:0] R_write_addr = 20'h00000;
    reg [15:0] R_write_data = 16'hABCD;

    reg R_read_request = 1'b0;
    wire S_read_grant, S_read_data_valid;
    reg [19:0] R_read_addr = 20'h00000;
    wire [15:0] S_read_data;

    sdram_ctrl
    sdram_ctrl_inst
    (
        .clk(clk_sdram),    // clock
        // READ agent
        .RdReq(R_read_request),
        .RdGnt(S_read_grant),
        .RdAddr(R_read_addr),
        .RdData(S_read_data),
        .RdDataValid(S_read_data_valid),
        // WRITE agent
        .WrReq(R_write_request),
        .WrGnt(S_write_grant),
        .WrAddr(R_write_addr),
        .WrData(R_write_data),
        // SDRAM chip connection
        .SDRAM_CKE(sdram_cke),
        .SDRAM_WEn(sdram_wen),
        .SDRAM_RASn(sdram_rasn),
        .SDRAM_CASn(sdram_casn),
        .SDRAM_BA(sdram_ba),	// SDRAM bank address
        .SDRAM_A(sdram_a),	// SDRAM address
        .SDRAM_DQ(sdram_d),     // SDRAM data
        .SDRAM_DQM(sdram_dqm)	// SDRAM byte select
    );
    assign sdram_clk = ~clk_sdram; // phase shifted 180 deg

    // RAM R/W state machine
    reg R_inc = 1'b0;
    reg [15:0] R_read_data_latch;
    reg [23:0] R_state_latch;
    reg [23:0] R_state;
    reg R_prev_read_data_valid;
    always @(posedge clk_sdram)
    begin
      if(R_state == 24'h110000)
      begin
        R_write_request <= 1'b1;
        //R_write_addr <= 20'h00000;
        //R_write_data <= 16'hABCD;
      end

      // R_write_addr <= R_state[15:0];
      R_write_data <= R_state[15:0];

      //if(S_write_grant == 1'b1)
      if(R_state == 24'h110003)
      begin
        // after ACK, remove request
        //R_state_latch <= R_state;
        R_write_request <= 1'b0;
      end

      if(R_state == 24'h112000)
      begin
        R_read_request <= 1'b1;
        R_read_addr <= 20'h00000;
      end

      // if(S_read_grant == 1'b1)
      if(R_state == 24'h112001)
      begin
        // after ACK, remove request
        // R_state_latch <= R_state; // display at which state we are
        R_read_request <= 1'b0;
      end

      R_prev_read_data_valid <= S_read_data_valid;
      if(R_prev_read_data_valid == 1'b0 && S_read_data_valid == 1'b1)
      begin
        R_state_latch <= R_state; // display at which state we are
        R_read_data_latch <= S_read_data;
      end
      R_state <= R_state + 1;
    end

    reg [127:0] R_display; // something to display
    always @(posedge clk_oled)
    begin
      R_display[63:48] <= R_write_data;
      R_display[40:16] <= R_write_addr;
      R_display[15:0] <= R_read_data_latch;
      R_display[124] <= R_write_request;
      R_display[120] <= S_write_grant;
      R_display[116] <= R_read_request;
      R_display[112] <= S_read_grant;
      R_display[108] <= S_read_data_valid;
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
