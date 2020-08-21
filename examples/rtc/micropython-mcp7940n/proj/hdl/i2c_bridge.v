`default_nettype none
module i2c_bridge
(
    input  wire       clk,    // any
    input  wire       clk_en, // 1-clk pulse, repeats 1.5-6 MHz
    input  wire [1:0] i,      // inputs
    output wire [1:0] t       // tristate 0->0 1->Z
);
  reg [1:0] state, next_state;

  always @(posedge clk)
    case(state)
      2'd0: begin
        if(i[0])
          next_state <= 3;
        else
          next_state <= 0;
      end

      2'd1: begin
        if(i[1])
          next_state <= 3;
        else
          next_state <= 1;
      end

      default: begin
        if(i[0]==0 && i[1]==1)
          next_state <= 0;
        else if(i[1]==0 && i[0]==1)
          next_state <= 1;
        else
          next_state <= 3;
      end
    endcase

  always @(posedge clk)
    if(clk_en)
      state <= next_state;

  assign t[1] = state == 2'd0 ? 0:1;
  assign t[0] = state == 2'd1 ? 0:1;

endmodule
