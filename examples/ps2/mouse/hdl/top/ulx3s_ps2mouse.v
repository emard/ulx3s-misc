module ulx3s_ps2mouse
#(
  parameter mousecore = 1 // 0-amiga 1-oberon
)
(
  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,
  inout usb_fpga_dp, usb_fpga_dn,
  output usb_fpga_pu_dp, usb_fpga_pu_dn,
  output wifi_gpio0
);
    // wifi_gpio0=1 keeps board from rebooting
    // hold btn0 to let ESP32 take control over the board
    assign wifi_gpio0 = btn[0];
    wire clk;
    assign clk = clk_25mhz;
    // enable pullups 1.5k to 3.3V
    assign usb_fpga_pu_dp = 1'b1;
    assign usb_fpga_pu_dn = 1'b1;

    reg [19:0] reset_counter;
    always @(posedge clk)
    begin
      if(btn[0] == 1'b0 && reset_counter[19] == 1'b0)
        reset_counter <= reset_counter + 1;
      if(btn[0] == 1'b1)
        reset_counter <= 0;
    end
    wire reset;
    assign reset = reset_counter[19];
    assign led[0] = reset;

    wire [7:0] xcount, ycount;

    generate
      if(mousecore == 0) // using amiga core
      begin
        wire ps2mdat_in, ps2mclk_in, ps2mdat_out, ps2mclk_out;
        assign usb_fpga_dp = ps2mclk_out ? 1'bz : 1'b0;
        assign usb_fpga_dn = ps2mdat_out ? 1'bz : 1'b0;
        assign ps2mclk_in = usb_fpga_dp;
        assign ps2mdat_in = usb_fpga_dn;
        wire [7:0] xcount, ycount;
        ps2mouse
        ps2mouse_amiga_inst
        (
          .clk(clk),
          .reset(reset),
          .ps2mdati(ps2mdat_in),
          .ps2mclki(ps2mclk_in),
          .ps2mdato(ps2mdat_out),
          .ps2mclko(ps2mclk_out),
          .xcount(xcount),
          .ycount(ycount),
          .btn(led[3:1])
        );
      end
      if(mousecore == 1) // using oberon core
      begin
        wire [27:0] mouse_out;
        MouseM
        ps2mouse_oberon_inst
        (
          .clk(clk),
          .rst(~reset), // active low
          .msclk(usb_fpga_dp),
          .msdat(usb_fpga_dn),
          .out(mouse_out)
        );
        assign xcount = mouse_out[7:0];
        assign ycount = mouse_out[19:12];
        assign led[3:1] = mouse_out[26:24];
      end
    endgenerate

    assign led[7:6] = ycount[1:0];
    assign led[5:4] = xcount[1:0];
    
endmodule
