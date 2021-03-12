// SPI reader for ADXL355 accelerometer
// enables smooth switch between direct mode to ADXL355
// and the mode with automatic read and BRAM buffering

`default_nettype none
module adxl355rd
#(
  cmd_read     = 8*2+1,      // SPI byte command that starts reading: 8*2+1=XDATA3, 17*2+1=FIFO_DATa
  len_read     = 9           // number of bytes to read
)
(
  input         clk, clk_en, // clk_en should be 1-clk pulse slower than 20 MHz
  // from esp23
  input         direct, // request direct: 0:buffering, 1:direct to ADXL355
  input         direct_mosi, direct_sclk, direct_csn,
  //output        direct_miso, // no mux, adxl_mosi can be always used
  // synchronous reading, start of 9-byte xyz sequence
  input         sync,
  // to ADXL355 chip
  output        adxl_mosi, adxl_sclk, adxl_csn, // max sclk = clk/2 or clk_en/2
  input         adxl_miso,
  // to BRAM for buffering
  output  [7:0] wrdata,
  output        wr, x // x is set together with wr at start of new 9-byte xyz sequence, x-axis
);
  reg r_direct; // allow switch when idle

  localparam index_total = (len_read+1)*16+4; // total index run for one xyz reading (cycles)
  localparam index_csn0 = 1;
  reg [7:0] index; // running index

  // internal wiring, before multiplexer  
  wire w_mosi, w_sclk, w_csn, w_miso;

  // direct/internal multiplex
  assign adxl_csn    = r_direct ? direct_csn  : w_csn;
  assign adxl_sclk   = r_direct ? direct_sclk : w_sclk;
  assign adxl_mosi   = r_direct ? direct_mosi : w_mosi;

  always @(posedge clk)
  begin
    if(index == index_total-1)
    begin
      if(sync && ~r_direct)
        index <= 0; // start new cycle
    end
    else // index != index_total-1
    begin
      if(clk_en)
        index <= index+1;
    end
  end

  reg r_csn = 1, r_sclk_en = 0, r_sclk, r_wr, r_x;
  reg [7:0] r_mosi, r_miso, r_shift, r_wrdata;

  always @(posedge clk)
  if(clk_en)
  begin
    r_csn     <= index == 1 ? 0 : index == index_total-2 ? 1 : r_csn;
    r_sclk_en <= index == 2 ? 1 : index == index_total-3 ? 0 : r_sclk_en;
    r_sclk    <= r_sclk_en  ? index[0] : 0;
    r_direct  <= index == index_total-2 ? direct : r_direct;
    r_wr      <= r_sclk_en  ? r_shift[7] : 0;
    r_x       <= r_sclk_en && index == 3;
  end

  always @(posedge clk)
  if(clk_en && ~index[0])
  begin
    r_mosi    <= index == 2 ? cmd_read : {r_mosi[6:0], 1'b0};
    r_shift   <= index == 2 ? 8'h01 : {r_shift[6:0], r_shift[7]};
    r_miso    <= {r_miso[6:0], adxl_miso};
    r_wrdata  <= r_shift[7] ? {r_miso[6:0], adxl_miso} : r_wrdata;
  end
  assign w_mosi = r_mosi[7];
  assign w_csn  = r_csn;
  assign w_sclk = r_sclk;

  assign wrdata = r_wrdata;
  assign wr     = r_wr;
  assign x      = r_x;

endmodule
`default_nettype wire
