// BTN debouncer
`default_nettype none
module btn_debounce
#(
  parameter bits = 16,
  parameter btns = 7
)
(
  input  clk, // 1-100 MHz
  input  [btns-1:0] btn,
  output [btns-1:0] debounce, rising, falling
);
  reg [bits:0] R_debounce;
  reg [btns-1:0] R_btn, R_btn_prev;
  always @(posedge clk)
  begin
    if(R_debounce[bits])
    begin
      if(R_btn != R_btn_prev)
        R_debounce <= 0;
      else
        R_btn <= btn;
      R_btn_prev <= R_btn;
    end
    else
    begin
      R_debounce <= R_debounce + 1;
    end
  end
  assign debounce = R_btn;
  assign rising   = R_btn & ~R_btn_prev;
  assign falling  = R_btn_prev & ~R_btn;

endmodule
