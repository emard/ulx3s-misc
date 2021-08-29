// SPI reader for ADXL355 accelerometer
// enables smooth switch between direct mode to ADXL355
// and the mode with automatic read and BRAM buffering

`default_nettype none
module adxl355rd
#(
  tag_addr_bits = 11  // 2**n number of chars in tag FIFO buffer (number of RAM address bits)
)
(
  input         clk, clk_en,   // clk_en should be 1-clk pulse slower than 20 MHz
  input         sclk_phase,    // 0:ADXL355 1:ADXRS290
  input         sclk_polarity, // 0:ADXL355 1:ADXRS290
  // from esp32
  input         direct, // request direct: 0:buffering, 1:direct to ADXL355
  output        direct_en, // grant direct access (signal for mux)
  // from tagger to internal FIFO
  input         tag_pulse, // pulse 1-clk-cycle inserts char "!"=0x21 with higher priority than tag_en
  input         tag_en, // 1-clk cycle to push one 6-bit char to tag buffer
  input   [5:0] tag, // input data going to tag FIFO buffer
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
  reg r_tag_latch = 0; // signal to latch tag data (pop from FIFO) or get pending pulse tag

  // tag_pulse has higher priority than tag_en
  reg r_pulse_tag = 0;
  always @(posedge clk)
  begin
    if(tag_pulse)
      r_pulse_tag <= 1;
    else
    begin
      if(r_tag_latch)
        r_pulse_tag <= 0;
    end
  end

  // tag_en for NMEA 6-bit data
  reg [5:0] tag_fifo[0:2**tag_addr_bits-1];
  reg [tag_addr_bits-1:0] r_wtag = 0, r_rtag = 0;
  always @(posedge clk)
  begin
    if(tag_en)
    begin // push to FIFO
      tag_fifo[r_wtag] <= tag;
      r_wtag <= r_wtag+1;
    end
  end

  reg [5:0] tag_fifo_rdata;
  always @(posedge clk)
    tag_fifo_rdata <= tag_fifo[r_rtag];

  reg [5:0] tag_data; // latched tag data to send
  always @(posedge clk)
  begin
    if(r_tag_latch)
    begin
      if(r_pulse_tag)
        tag_data <= 6'h21;
      else
      begin
        if(r_wtag == r_rtag) // FIFO empty?
          tag_data <= 6'h20; // space char " " when FIFO empty
        else // data in FIFO, pop one
        begin
          //tag_data <= tag_fifo[r_rtag]; // was working before
          tag_data <= tag_fifo_rdata; // will it work now
          r_rtag <= r_rtag+1;
        end
      end
    end
  end

  reg [7:0] cmd_read  = 1; // holds the spi command byte 1:read id
  reg [3:0] bytes_len = 10; // holds the spi transfer length including command byte

  reg r_direct; // allow switch when idle
  reg [7:0] index = {4'd10, 4'h6}; // running index, start as finished

  // internal wiring, before multiplexer  
  wire w_mosi, w_sclk, w_csn, w_miso;

  // direct/internal multiplex
  assign adxl_csn    = w_csn;
  assign adxl_sclk   = w_sclk;
  assign adxl_mosi   = w_mosi;

  always @(posedge clk)
  begin
    if(index == {bytes_len, 4'h6}) // end of sequence
    begin
      if(sync && ~r_direct)
      begin
        index <= 0; // start new cycle
        cmd_read <= cmd;
        bytes_len <= len;
        r_tag_latch <= 1;
      end
    end
    else // end not yet
    begin
      if(clk_en)
        index <= index+1;
      r_tag_latch <= 0;
    end
  end

  reg [2:0] r_tag_data_i = 0; // bit-index for reading latched tag data
  reg r_tag_data_en = 0; // toggled at wr16 for LSB to be tagged
  reg r_csn = 1, r_sclk_en = 0, r_sclk, r_wr = 0, r_wr16 = 0, r_x = 0;
  //wire r_sclk;
  reg [7:0] r_mosi, r0_miso, r1_miso, r_shift, r0_wrdata, r1_wrdata;
  always @(posedge clk)
  if(clk_en)
  begin
    r_csn     <= index == 1 ? 0 : index == {bytes_len, 4'h5} ? 1 : r_csn;
    r_sclk_en <= index == 3 ? 1 : index == {bytes_len, 4'h4} ? 0 : r_sclk_en;
    r_sclk    <= ( (index[0] ^ sclk_phase) & r_sclk_en) ^ sclk_polarity; // normal ADXL355 works with this
    r_direct  <= index == {bytes_len, 4'h6} ? direct : r_direct;
  end
  //assign r_sclk = ( (index[0] ^ sclk_phase) & r_sclk_en) ^ sclk_polarity; // debug ADXRS290 works with this

  wire [7:0] w0_miso = {r0_miso[6:0], adxl0_miso};
  wire [7:0] w1_miso = {r1_miso[6:0], adxl1_miso};
  always @(posedge clk)
  if(clk_en && ~index[0])
  begin
    r_mosi    <= index[7:1] == 2 ? cmd_read : {r_mosi[6:0], 1'b0};
    r_shift   <= index[7:1] == 2 ? 8'h01 : {r_shift[6:0], r_shift[7]};
    r0_miso   <= w0_miso;
    r0_wrdata <= r_shift[7] ? (r_tag_data_en ? {w0_miso[7:1], tag_data[r_tag_data_i]  } : w0_miso) : r0_wrdata;
    r1_miso   <= w1_miso;
    r1_wrdata <= r_shift[7] ? (r_tag_data_en ? {w1_miso[7:1], tag_data[r_tag_data_i+3]} : w1_miso) : r1_wrdata;
    r_wr      <= r_shift[7] && index[7:1] != 10 && r_sclk_en ? 1 : 0; // every byte
    r_wr16    <= r_shift[7] && index[7:1] != 10 && index[7:1] != 34 && index[7:1] != 58 && index[7:1] != 82 && r_sclk_en ? 1 : 0; // 16-bit accel, skip every 3rd byte
    r_x       <= index[7:1] == 18; // should trigger at the same time as first r_wr and r_wr16
  end
  else
  begin
    // only 1-clk-cycle write
    r_wr      <= 0;
    r_wr16    <= 0;
  end

  always @(posedge clk)
  begin
    r_tag_data_en <= index[7:1] == 0 ? 0 : r_wr16 ? ~r_tag_data_en : r_tag_data_en;
    r_tag_data_i  <= index[7:1] == 0 ? 0 : r_wr16 &  r_tag_data_en ? r_tag_data_i+1 : r_tag_data_i;
    //r_tag_latch   <= index == 0 && clk_en == 1;
  end

  // 6-byte buffer
  localparam r1_wrbuf_len = 6;
  reg [7:0] r1_wrbuf[0:r1_wrbuf_len-1]; // 6-byte buffer for adxl1_miso
  reg [2:0] r1_windex = 0; // this core writes
  always @(posedge clk)
  begin
    if(r_wr16)
      r1_wrbuf[r1_windex] <= r1_wrdata; // normal
    r1_windex <= index[7:1] == 2 ? 0 : r_wr16 ? r1_windex + 1 : r1_windex;
  end

  // 6-byte buffer read process (to get buffer content written by top core)
  reg [3:0] prev_index4 = 4'h6; // running LSB hex digit of index, start as finished
  reg [$clog2(r1_wrbuf_len-1)-1:0] r1_rindex = r1_wrbuf_len; // this core reads, toplevel should write to BRAM buffer: 6-end
  reg r_wr1 = 0; // second adxl channel write
  always @(posedge clk)
  begin
    prev_index4 <= index[3:0];
    if(r1_rindex == r1_wrbuf_len) // stopeed
    begin
      if(index[7:4] == bytes_len && index[3:0] == 4'h6 && prev_index4 == 4'h5)
      begin
        // index just switched to end position, start writing adxl1
        r1_rindex <= 0;
        r_wr1 <= 1;
      end
    end
    else
    begin
      r1_rindex <= r1_rindex + 1;
      if(r1_rindex == r1_wrbuf_len-1)
        r_wr1 <= 0;
    end
  end

  assign w_mosi = r_mosi[7];
  assign w_csn  = r_csn;
  assign w_sclk = r_sclk;

  assign wrdata = r_wr1 ? r1_wrbuf[r1_rindex] : r0_wrdata;
  assign wr     = r_wr   | r_wr1;
  assign wr16   = r_wr16 | r_wr1;
  assign x      = r_x;
  
  assign direct_en = r_direct;

endmodule
`default_nettype wire
