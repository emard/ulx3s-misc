// generates triangle wave

module trianglewave
#(
  parameter C_delay = 10, // bits for delay part of the counter
  parameter C_pcm_bits = 12 // how many bits for PCM output
)
(
  input clk, // required to run PWM
  output signed [C_pcm_bits-1:0] pcm // 12-bit unsigned PCM output
);

    reg [C_delay+C_pcm_bits-1:0] R_counter; // PWM counter register
    reg R_direction;
    
    always @(posedge clk)
    begin
      if(R_direction == 1'b1)
        R_counter <= R_counter + 1;
      else
        R_counter <= R_counter - 1;
    end

    always @(posedge clk)
    begin
      if( R_counter[C_delay+C_pcm_bits-1:C_delay] == ~{12'd1770} && R_direction == 1'b0)
        R_direction <= 1'b1; // from now on, count forwards
      if( R_counter[C_delay+C_pcm_bits-1:C_delay] == 12'd1770 && R_direction == 1'b1)
        R_direction <= 1'b0; // from now on, count backwards
    end
    
    assign pcm = R_counter[C_delay+C_pcm_bits-1:C_delay];
endmodule
