// push BTN1 to play triangle wave instead of default sine wave

module top_audio
(
  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,
  output [3:0] audio_l, audio_r, audio_v,
  inout [27:0] gp, gn,
  output wifi_gpio0
);
    // wifi_gpio0=1 keeps board from rebooting
    // hold btn0 to let ESP32 take control over the board
    assign wifi_gpio0 = btn[0];

    wire [11:0] pcm_trianglewave;
    // triangle wave generator /\/\/
    trianglewave
    #(
      .C_delay(6) // smaller value -> higher freq
    )
    trianglewave_instance
    (
      .clk(clk_25mhz),
      .pcm(pcm_trianglewave)
    );


    wire [11:0] pcm_sinewave;
    // sine wave generator ~~~~
    sinewave
    #(
      .C_delay(10) // smaller value -> higher freq
    )
    sinewave_instance
    (
      .clk(clk_25mhz),
      .pcm(pcm_sinewave)
    );

    wire [11:0] pcm = btn[1] ? pcm_trianglewave : pcm_sinewave;

    assign led = pcm[11:4];

    // analog output to classic headphones
    wire [3:0] dac;
    dacpwm
    dacpwm_instance
    (
      .clk(clk_25mhz),
      .pcm(pcm),
      .dac(dac)
    );
    assign audio_l = dac;
    assign audio_r = dac;

    // digital output to SPDIF
    wire [23:0] pcm_24s;
    assign pcm_24s[23] = pcm[11];
    assign pcm_24s[22:11] = pcm;
    assign pcm_24s[10:0] = 11'b0;
    wire spdif;
    spdif_tx
    #(
      .C_clk_freq(25000000),
      .C_sample_freq(48000)
    )
    spdif_tx_instance
    (
      .clk(clk_25mhz),
      .data_in(pcm_24s),
      .spdif_out(spdif)
    );

    assign audio_v[3:2] = 2'b00;
    assign audio_v[1] = spdif; // 0.4V at SPDIF (standard: 0.6V MAX)
    assign audio_v[0] = 1'b0;

    parameter i2s_fmt = 0; // 0-i2s standard, 1-left justified
    wire bck, din, lrck;
    i2s
    #(
      .fmt(i2s_fmt),
      .div(3)
    )
    i2s_instance
    (
      .clk(clk_25mhz),
      .left(pcm_24s[23:8]), // sine default, BTN0 pressed -> triangle wave
      .right({pcm_sinewave[11],pcm_sinewave,3'b0}), // sine always
      .din(din),
      .bck(bck),
      .lrck(lrck)
    );
    
    assign gp[7]  = i2s_fmt;     // FMT 0=i2s
    assign gp[8]  = lrck;        // LCK
    assign gp[9]  = din;         // DIN
    assign gp[10] = bck;         // BCK
    assign gp[11] = 1'b0;        // SCL
    assign gp[12] = 1'b1;        // DMP
    assign gp[13] = 1'b1;        // FLT

    assign gn[7]  = i2s_fmt;     // FMT 0=i2s
    assign gn[8]  = lrck|btn[6]; // LCK
    assign gn[9]  = din;         // DIN
    assign gn[10] = bck;         // BCK
    assign gn[11] = 1'b0;        // SCL
    assign gn[12] = 1'b1;        // DMP
    assign gn[13] = 1'b1;        // FLT
endmodule
