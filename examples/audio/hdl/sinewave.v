// generates sine wave
// using discrete-time evaluation of the
// physical model of a sprung mass lossless mechanical oscillator

module sinewave
#(
  parameter C_delay = 8, // sample rate = 2^-n
  parameter C_pcm_bits = 12, // output PCM bits
  parameter C_spd_bits = 10,
  parameter C_pos_to_spd_shift = 8, // mechanical "spring" stiffness = 2^-n
  parameter C_spd_to_pos_shift = 3, // mechanical "mass" = 2^-n
  parameter C_pos_init = 0, // initial position = 0
  parameter C_spd_init = 277 // initial speed 340 sets max amplitude that fits into 12-bit
)
(
  input clk,
  output signed [C_pcm_bits-1:0] pcm // 12-bit signed PCM output
);
    reg signed [C_spd_bits-1:0] R_spd = C_spd_init;
    reg signed [C_pcm_bits-1:0] R_pos = C_pos_init;
    wire signed [C_spd_bits-1:0] S_pos_shift;
    assign S_pos_shift =
    {
      {(C_spd_bits-(C_pcm_bits-C_pos_to_spd_shift)){R_pos[C_pcm_bits-1]}}, // 6 bit sign expansion, 6+4 = 10 bit 
      R_pos[C_pcm_bits-1:C_pos_to_spd_shift] // 12->4 bit
    };
    wire signed [C_pcm_bits-1:0] S_pos_next;
    wire signed [C_pcm_bits-1:0] S_spd_shift;
    assign S_spd_shift =
    {
      {(C_pcm_bits-(C_spd_bits-C_spd_to_pos_shift)){R_spd[C_spd_bits-1]}}, // 5 bit sign expansion, 5+7 = 12 bit
      R_spd[C_spd_bits-1:C_spd_to_pos_shift] // 10->7 bit
    };
    assign S_pos_next = R_pos + S_spd_shift;

    reg [C_pcm_bits-1:0] R_pcm;
    reg [C_delay-1:0] R_delay; // counter to slow down
    always @(posedge clk)
    begin
      if( (|(R_delay[C_delay-1:1])) == 1'b0 )
      begin
        // every 2nd clock calculates next value of the sine wave
        if( R_delay[0] == 1'b0) // alternate
          R_pos <= S_pos_next; // apply speed to position
        else
          R_spd <= R_spd - S_pos_shift; // apply acceleration to speed
      end
      R_delay <= R_delay + 1;
    end
    
    assign pcm = R_pos;
endmodule
