module top_hex_480x272
#(
  parameter c_counter_bits = 8
)
(
  input         clk_25mhz,
  input   [6:0] btn,
  output  [7:0] led,
  inout  [27:0] gp, gn,
  output        wifi_gpio0
);
    // wifi_gpio0=1 keeps board from rebooting
    // hold btn0 to let ESP32 take control over the board
    assign wifi_gpio0 = btn[0];

    // clock generator
    wire clk_175MHz, clk_25MHz, clk_locked;
    clk_25_175_25
    clock_instance
    (
      .clk25_i(clk_25mhz),
      .clk175_o(clk_175MHz),
      .clk25_o(clk_25MHz),
      .locked(clk_locked)
    );
    
    wire clk_pixel = clk_25MHz;
    wire clk_shift = clk_175MHz;
    
    reg [2:0] areg; // 0-7 ADC register
    reg [c_counter_bits-1:0] counter;
    reg [4:0] cscounter; // 0-31
    
    always @(posedge clk_pixel)
      counter <= counter + 1;

    wire adc_reset = ~btn[0];
    wire adc_convstn = counter[c_counter_bits-1:c_counter_bits-3] == 6 ? 1 : 0;
    wire adc_rdn = cscounter[4];
    wire adc_csn = adc_rdn;
    wire adc_busy;
    wire adc_firstdata;
    wire [15:0] adc_data;

    // *** begin ULX3S-TO-ADC CONNECTION PINOUT ***
    assign gn[27] = adc_reset;
    assign gp[27] = adc_convstn;
    assign gp[26] = adc_rdn;
    assign gn[26] = adc_csn;
    assign gn[17] = 1'bz;
    assign adc_busy = gn[17];
    assign gn[13] = 1'bz;
    assign adc_firstdata = gn[13]; // have PULLMODE=DOWN in constraints
    assign gp[25:18] = 8'hzz;
    assign gn[25:18] = 8'hzz;
    generate
      genvar i;
      for(i = 0; i < 8; i++)
      begin
        assign adc_data[15-i*2] = gp[18+i];
        assign adc_data[14-i*2] = gn[18+i];
      end
    endgenerate
    // *** end ULX3S-TO-ADC CONNECTION PINOUT ***

    parameter C_bits = 256;
    reg [C_bits-1:0] R_display; // something to display

    reg [15:0] busycnt = 16'hABCD;
    reg [1:0] R_adc_busy;
    reg [15:0] R_adc_data[0:7];
    always @(posedge clk_pixel)
    begin
      if(R_adc_busy == 2'b10)
        busycnt <= busycnt + 1;
      R_adc_busy <= { adc_busy, R_adc_busy[1] };
      if(adc_busy)
      begin
        cscounter <= ~0;
      end
      else
      begin
        cscounter <= cscounter + 1;
        if(adc_firstdata)
          areg <= 0;
        else
        begin
          if(cscounter == 16)
            R_adc_data[areg] <= adc_data;
          if(cscounter == 30)
            areg <= areg + 1;
        end
      end
    end
    
    always @(posedge clk_pixel)
      R_display[127:0] <= { busycnt, R_adc_data[6], R_adc_data[5], R_adc_data[4], R_adc_data[3], R_adc_data[2], R_adc_data[1], R_adc_data[0] };

    parameter C_color_bits = 16; 
    wire [9:0] x;
    wire [9:0] y;
    // for reverse screen:
    wire [9:0] rx = 480-4-x;
    wire [C_color_bits-1:0] color;
    hex_decoder_v
    #(
        .c_data_len(C_bits),
        .c_row_bits(5), // 2**n digits per row (4*2**n bits/row) 3->32, 4->64, 5->128, 6->256 
        .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
        .c_font_file("hex_font.mem"),
        .c_x_bits(9),
        .c_y_bits(4),
	.c_color_bits(C_color_bits)
    )
    hex_decoder_v_inst
    (
        .clk(clk_pixel),
        .data(R_display),
        .x(rx[9:1]),
        .y(y[4:1]),
        .color(color)
    );

    // VGA signal generator
    wire [7:0] vga_r, vga_g, vga_b;
    assign vga_r = {color[15:11],color[11],color[11],color[11]};
    assign vga_g = {color[10:5],color[5],color[5]};
    assign vga_b = {color[4:0],color[0],color[0],color[0]};
    wire vga_hsync, vga_vsync, vga_blank;
    vga
    #(
      .C_resolution_x(480),
      .C_hsync_front_porch(24),
      .C_hsync_pulse(48),
      .C_hsync_back_porch(72),
      .C_resolution_y(272),
      .C_vsync_front_porch(1),
      .C_vsync_pulse(3),
      .C_vsync_back_porch(19),
      .C_bits_x(10),
      .C_bits_y(10)
    )
    vga_instance
    (
      .clk_pixel(clk_pixel),
      .clk_pixel_ena(1'b1),
      .test_picture(1'b0), // enable test picture generation
      .beam_x(x),
      .beam_y(y),
      .vga_hsync(vga_hsync),
      .vga_vsync(vga_vsync),
      .vga_blank(vga_blank)
    );
    

    // VGA to digital video converter
    wire [3:0] lvds;
    vga2lvds
    vga2lvds_instance
    (
      .clk_pixel(clk_pixel),
      .clk_shift(clk_shift),
      .in_red(vga_r),
      .in_green(vga_g),
      .in_blue(vga_b),
      .in_hsync(vga_hsync),
      .in_vsync(vga_vsync),
      .in_blank(vga_blank),
      .out_lvds(lvds)
    );
    
    assign gp[6:3] =  lvds;
    assign gn[6:3] = ~lvds;
    assign gn[8] = 1;

    /*
    // unused ?
    assign gp[2:1] = 0;
    assign gn[2:1] = 0;
    assign gp[8] = 0;
    */

    assign led[7:6] = 0;
    assign led[5] = adc_convstn;
    assign led[4] = adc_busy;
    assign led[3] = adc_reset;
    assign led[0] = vga_vsync;
    assign led[1] = vga_hsync;
    assign led[2] = vga_blank;

endmodule
