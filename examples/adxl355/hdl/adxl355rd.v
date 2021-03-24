// SPI reader for ADXL355 accelerometer
// enables smooth switch between direct mode to ADXL355
// and the mode with automatic read and BRAM buffering

`default_nettype none
module adxl355rd
(
  input         clk, clk_en, // clk_en should be 1-clk pulse slower than 20 MHz
  // from esp23
  input         direct, // request direct: 0:buffering, 1:direct to ADXL355
  output        direct_en, // grant direct access (signal for mux)
  //output        direct_miso, // no mux, adxl_mosi can be always used
  // synchronous reading, start of 9-byte xyz sequence
  input         sync,
  input   [7:0] cmd, // SPI command byte, first to send: 0*2+1: reads id, 8*2+1: reads current, 17*2+1: read fifio
  input   [3:0] len, // bytes length, including cmd byte
  // to ADXL355 chip
  output        adxl_mosi, adxl_sclk, adxl_csn, // max sclk = clk/2 or clk_en/2
  input         adxl0_miso, adxl1_miso,
  // to BRAM for buffering
  output  [7:0] wrdata,
  output        wr, wr16, // wr writes every byte, wr16 is for 16-bit accel, skips every 3rd byte
  output        x // x is set together with wr at start of new 9-byte xyz sequence, x-axis
);
  reg [7:0] cmd_read  = 1; // holds the spi command byte 1:read id
  reg [3:0] bytes_len = 10; // holds the spi transfer length including command byte

  reg r_direct; // allow switch when idle
  reg [7:0] index = {4'd10, 4'h4}; // running index, start as finished

  // internal wiring, before multiplexer  
  wire w_mosi, w_sclk, w_csn, w_miso;

  // direct/internal multiplex
  assign adxl_csn    = w_csn;
  assign adxl_sclk   = w_sclk;
  assign adxl_mosi   = w_mosi;

  always @(posedge clk)
  begin
    if(index == {bytes_len, 4'h4}) // end of sequence
    begin
      if(sync && ~r_direct)
      begin
        index <= 0; // start new cycle
        cmd_read <= cmd;
        bytes_len <= len;
      end
    end
    else // end not yet
    begin
      if(clk_en)
        index <= index+1;
    end
  end

  reg r_csn = 1, r_sclk_en = 0, r_sclk, r_wr = 0, r_wr16 = 0, r_x = 0;
  reg [7:0] r_mosi, r0_miso, r1_miso, r_shift, r0_wrdata, r1_wrdata;

  always @(posedge clk)
  if(clk_en)
  begin
    r_csn     <= index == 1 ? 0 : index == {bytes_len, 4'h3} ? 1 : r_csn;
    r_sclk_en <= index == 2 ? 1 : index == {bytes_len, 4'h2} ? 0 : r_sclk_en;
    r_sclk    <= r_sclk_en  ? index[0] : 0;
    r_direct  <= index == {bytes_len, 4'h4} ? direct : r_direct;
  end

  always @(posedge clk)
  if(clk_en && ~index[0])
  begin
    r_mosi    <= index[7:1] == 1 ? cmd_read : {r_mosi[6:0], 1'b0};
    r_shift   <= index[7:1] == 1 ? 8'h01 : {r_shift[6:0], r_shift[7]};
    r0_miso   <= {r0_miso[6:0], adxl0_miso};
    r0_wrdata <= r_shift[7] ? {r0_miso[6:0], adxl0_miso} : r0_wrdata;
    r1_miso   <= {r1_miso[6:0], adxl1_miso};
    r1_wrdata <= r_shift[7] ? {r1_miso[6:0], adxl1_miso} : r1_wrdata;
    r_wr      <= r_shift[7] && index[7:1] != 9 && r_sclk_en ? 1 : 0; // every byte
    r_wr16    <= r_shift[7] && index[7:1] != 9 && index[7:1] != 33 && index[7:1] != 57 && index[7:1] != 81 && r_sclk_en ? 1 : 0; // 16-bit accel, skip every 3rd byte
    r_x       <= index[7:1] == 17; // should trigger at the same time as first r_wr and r_wr16
  end
  else
  begin
    // only 1-clk-cycle write
    r_wr      <= 0;
    r_wr16    <= 0;
  end

  // 12-byte buffer
  reg [7:0] r1_wrbuf[0:5]; // 12-byte buffer for adxl1_miso
  reg [2:0] r1_windex = 0; // this core writes
  always @(posedge clk)
  begin
    if(r_wr16)
      r1_wrbuf[r1_windex] <= r1_wrdata; // normal
    r1_windex <= index[7:1] == 1 ? 0 : r_wr16 ? r1_windex + 1 : r1_windex;
  end

  // 6-byte buffer read process (to get buffer content written by top core)
  reg [3:0] prev_index4 = 4'h4; // running LSB hex digit of index, start as finished
  reg [2:0] r1_rindex = 6; // this core reads, toplevel should write to BRAM buffer: 6-end
  reg r_wr1 = 0; // second adxl channel write
  always @(posedge clk)
  begin
    prev_index4 <= index[3:0];
    if(r1_rindex == 6) // stopeed
    begin
      if(index[7:4] == bytes_len && index[3:0] == 4'h4 && prev_index4 == 4'h3)
      begin
        // index just switched to end position, start writing adxl1
        r1_rindex <= 0;
        r_wr1 <= 1;
      end
    end
    else
    begin
      r1_rindex <= r1_rindex + 1;
      if(r1_rindex == 5)
        r_wr1 <= 0;
    end
  end

  assign w_mosi = r_mosi[7];
  assign w_csn  = r_csn;
  assign w_sclk = r_sclk;

  assign wrdata = r_wr1 ? r1_wrbuf[r1_rindex] : r0_wrdata;
  assign wr     = r_wr;
  assign wr16   = r_wr16 | r_wr1;
  assign x      = r_x;
  
  assign direct_en = r_direct;

endmodule
`default_nettype wire
