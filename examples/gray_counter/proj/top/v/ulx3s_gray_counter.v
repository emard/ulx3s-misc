// (c)EMARD
// License=BSD
// module to bypass user input and usbserial to esp32 wifi
// no timescale needed

module ulx3s_gray_counter
(
input wire clk_25mhz,
output wire ftdi_rxd,
input wire ftdi_txd,
inout wire ftdi_ndtr,
inout wire ftdi_nrts,
inout wire ftdi_txden,
output wire wifi_rxd,
input wire wifi_txd,
inout wire wifi_en,
inout wire wifi_gpio0,
inout wire wifi_gpio2,
inout wire wifi_gpio15,
inout wire wifi_gpio16,
output wire [7:0] led,
input wire [6:0] btn,
input wire [0:3] sw,
output wire oled_csn,
output wire oled_clk,
output wire oled_mosi,
output wire oled_dc,
output wire oled_resn,
inout wire [27:0] gp,
inout wire [27:0] gn
);

  wire S_enable;
  reg [23:0] R_counter;

  // TX/RX passthru
  assign ftdi_rxd = wifi_txd;
  assign wifi_rxd = ftdi_txd;
  assign wifi_en = 1'b1;
  assign wifi_gpio0 = btn[0];
  always @(posedge clk_25mhz) begin
    if(R_counter[23] == 1'b1) begin
      R_counter <= {24{1'b0}};
    end
    else begin
      R_counter <= R_counter + 1;
    end
  end

  assign S_enable = R_counter[(23)];
  gray_counter
  #(
    .bits(8)
  )
  gray_inst
  (
    .clk(clk_25mhz),
    .reset(btn[1]),
    .enable(S_enable),
    .gray_count(led)
  );

endmodule
