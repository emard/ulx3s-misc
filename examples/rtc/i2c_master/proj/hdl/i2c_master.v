`timescale 1 ns / 1 ps

// I2C Simple Master for typical 7-bit EEPROM-like slaves.
// Not multi-master capable.

`default_nettype none

module i2c_master
#(
  parameter freq = 25 // MHz
)
(
  input wire        sys_clock,  // System clock, wr_ctrl should be synchronous to this
  input wire        reset,      // power-on reset - puts I2C bus into idle state
  inout wire        SDA,        // I2C Serial data line, pulled high at board level
  inout wire        SCL,        // I2C Serial clock line, pulled high at board level
  input wire [31:0] ctrl_data,  // Data bus for writing the control register
  input wire        wr_ctrl,    // Write enable for control register, also starts I2C cycles
  output reg [31:0] status      // Status of I2C including most recently read data
);

reg         float_sda;  // This is essentially SDA when we are sourcing it (open drain at pin)
reg         float_scl;  // This is essentially SCL when we are sourcing it (open drain at pin)
wire        sda_in;     // Feedback from the IOB pin for SDA
wire        scl_in;     // Feedback from the IOB pin for SCL

// I/O buffers for the I2C open-drain signals
// Note that even if no slaves drive SCL, you need to use feedback
// to sense the rising edge of SCL to be sure to meet hold time.
assign scl_in = SCL;
assign SCL = float_scl ? 1'bZ : 1'b0;

assign sda_in = SDA;
assign SDA = float_sda ? 1'bZ : 1'b0;

localparam  t_hd_sta = 4 * freq,        // Hold time on START condition, 4.0us from spec
            t_low = 5 * freq,           // SCL low time 4.7us from spec
            t_high = 5 * freq,          // SCL high time 4.0us from spec, but cycle time must be 10us
            t_su_sta = 5 * freq,        // SDA, SCL high before asserting start, 4.7us from spec
            t_su_dat = (freq >> 2) + 1, // Data valid to SCL rising, 250ns from spec
            t_hold = (freq >> 1) + 1,   // SCL falling to SDA changing 0 from spec, 0.5us for AD9888
            t_su_sto = 4 * freq;        // SCL high to SDA high for STOP condition, 4us from spec

localparam time_width = clogb2(t_low + 1); // Declare enough bits to hold maximum delay (5 us)

reg [time_width-1:0] timer;

// Ceiling of log base 2 from the Verilog Language Reference Manual:
function integer clogb2;
  input [31:0] value;
  begin
    value = value - 1;
    for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1)
      value = value >> 1;
  end
endfunction

reg [31:0] ctrl_reg;    // I2C control register
// Bit definitions:
//  31    Read / not write.
//  30    Repeated Start.  On read cycles setting this bit uses repeated start instad of stop start sequence.
//  29:23 Reserved.
//  22:16 7-bit I2C address of slave.
//  15:8  Register Subaddress
//  7:0   Data to write.  Don't care on read cycles.

//reg [31:0] status;      // I2C status register
// Bit definitions
//  31    Busy.  Not ready to accept new control register writes.
//  30    Address NACK.  Last address cycle resulted in no acknowledge from slave.
//  29    Data NACK.  Last data write cycle resulted in no acknowledge from slave.
//  28    Read.  Most recently completed cycle was a read.  Data in bits 7:0 is valid.
//  27    Overrun.  An attempt was made to write the ctrl_reg while busy.  Cleared
//        on successful write of ctrl_reg.
//  26    Initializing - waiting for SDA to go high after module reset
//  25:8  Reserved.  Tied to zero.
//  7:0   Read data.  Valid after a read cycle when bit 28 is set.

// Write 'h44 to register 'h55 in I2C slave 'h66
// assign ctrl_data = 32'h00665544;

// Write 'h20 to register 'h06 in I2C slave 'h6F
// assign ctrl_data = 32'h006F0620;

// Read from register 'h00 (seconds) in I2C slave 'h6F (RTC MCP7940N)
// assign ctrl_data = 32'h006F0000;

reg [26:0] shift_reg; // Data to shift out.  Includes ack positions: 1 = NACK or slave ack.

reg [4:0] bit_count;  // Counts bits during shift states.

reg [3:0] state;      // Main state machine state variable
reg [3:0] rtn_state;  // Return state for "subroutines"

reg sda, scl;         // debounced, deglitched SDA and SCL inputs

reg wr_cyc;           // Every access starts with a write cycle for subaddress.

reg [7:0] read_data;  // Input shift register for reads

reg [3:0] scl_startup_count;  // Clock SCL at least 12 times after SDA is detected high

// Debounce and deglitch input signals
reg [3:0] sda_sr, scl_sr;
always @ (posedge sys_clock or posedge reset)
if (reset)
  begin
    sda_sr <= 4'b1111;  // Start up assuming quiescent state of inputs
    sda <= 1;
    scl_sr <= 4'b1111;  // Start up assuming quiescent state of inputs
    scl <= 1;
  end
else
  begin
    sda_sr <= {sda_sr[2:0], sda_in};
    if (sda_sr == 4'b0000) sda <= 0;
    else if (sda_sr == 4'b1111) sda <= 1;
    scl_sr <= {scl_sr[2:0], scl_in};
    if (scl_sr == 4'b0000) scl <= 0;
    else if (scl_sr == 4'b1111) scl <= 1;
  end

// Define states:
localparam  pre_start_up = 0,
            start_up = 1,
            idle = 2,
            start = 3,
            clock_low = 4,
            shift_data = 5,
            clock_high = 6,
            stop = 7,
            spin = 15;

always @ (posedge sys_clock or posedge reset)
if (reset)
  begin
    timer <= t_low;
    state <= pre_start_up;
    rtn_state <= pre_start_up;
    ctrl_reg <= 0;
    status <= 32'h84000000; // Busy, initializing
    shift_reg <= {27{1'b1}};
    bit_count <= 0;
    float_sda <= 1;
    float_scl <= 1;
    wr_cyc <= 1;
    read_data <= 0;
    scl_startup_count <= 0;
  end
else
  begin
    if (wr_ctrl)
      begin
        if (status[31]) // busy
          begin
            status[27] <= 1;  // Set overrun flag on unsuccessful attempt to write ctrl_reg
          end
        else // not busy
          begin
            ctrl_reg <= ctrl_data;
            status[27] <= 0;  // Clear overrun flag on successful write to ctrl_reg
          end
      end
    case (state)
      // In pre-start-up state wait for SDA to go high while clocking SCL as necessary
      pre_start_up:
        begin
          if (timer == 0) // every 5 us
            begin
              if (float_scl)
                begin
                  if (sda && (scl_startup_count == 12))  // quiescent?
                    begin
                      scl_startup_count <= 0;
                      state <= start_up;
                    end
                  else
                    begin
                      float_scl <= 0; // Start another SCL clock cycle if SDA is still low
                      timer <= t_low;
                      scl_startup_count <= scl_startup_count + 1;
                    end
                end
              else  // Currently driving SCL
                begin
                  float_scl <= 1; // Release SCL
                  timer <= t_low;
                end
            end
          else if (scl | !float_scl) // Start timing after rising edge of SCL if not driven
            begin
              timer <= timer - 1;
            end
        end
      // In start-up state, generate a start and stop with no clocks in between
      start_up:
        begin
          if (timer == 0) // every 5 us
            begin
              timer <= t_low;
              scl_startup_count <= scl_startup_count + 1;
              if (scl_startup_count == 2) float_sda <= 0; // Create a start condition
              if (scl_startup_count == 12) float_sda <= 1; // Create a stop condition
              if (scl_startup_count == 15) state <= idle;
            end
          else
            begin
              timer <= timer - 1;
            end
        end
      idle:
        begin
          float_sda <= 1;
          float_scl <= 1;
          wr_cyc <= 1;
          status[31] <= 0;  // Not busy
          status[26] <= 0;  // Done initialization
          if (wr_ctrl & !status[31])  // successful write to ctrl_reg
            begin
              state <= start;
              status[31] <= 1;  // go busy
            end
        end
      start:
        begin
          // Create high to low transition on SDA.
          // Both SDA and SCL were high at least 4.7us before entering this state
          float_sda <= 0;
          float_scl <= 1;
          if (!sda) // Continue when we see sda driven low
            begin
              // 7-bit ADDR, R/WN, Slave Ack, 8-bit Subaddr, Slave Ack, 8-bit Data, Slave Ack
              // Data byte and final Slave Ack do not apply for reads
              // For Stop then start, SDA must be low after last ack cycle.
              // For repeated start, SDA must be high after last ack cycle.
              if (ctrl_reg[31])   // reading requires subaddr write then data read
                if (wr_cyc)
                  shift_reg <= {ctrl_reg[22:16],1'b0,1'b1,ctrl_reg[15:8],1'b1,ctrl_reg[30],7'b0,1'b0};
                else
                  shift_reg <= {ctrl_reg[22:16],1'b1,1'b1,8'hff,1'b1,8'b0,1'b0};
              else                // Writing
                shift_reg <= {ctrl_reg[22:16],1'b0,1'b1,ctrl_reg[15:8],1'b1,ctrl_reg[7:0],1'b1};
              bit_count <= 0;
              timer <= t_hd_sta;  // 4.0us from the spec
              rtn_state <= clock_low;
              state <= spin;
            end
        end
      clock_low:
        begin
          // Assert SCL low and when it is low, wait for t_hold before changing SDA
          float_scl <= 0;
          if (!scl) // Continue when SCL line has gone low
            begin
              timer <= t_hold; // extra 0.5 us for AD9888
              rtn_state <= shift_data;
              state <= spin;
            end
        end
      shift_data:
        begin
          // Shift data onto the SDA line
          float_sda <= shift_reg[26];
          shift_reg <= {shift_reg[25:0],1'b0};  // shift left
          timer <= t_low; // 4.7us min from spec
          rtn_state <= clock_high;
          state <= spin;
        end
      clock_high:
        begin
          // Release low drive on SCL and when it goes high
          // sample SDA and move on
          float_scl <= 1;
          if (scl)
            begin
              bit_count <= bit_count + 1;
              if (bit_count == 8) // Address ACK cycle
                begin
                  status[30] <= sda;  // SDA should be driven low for slave ACK
                end
              else if ((bit_count == 17) & wr_cyc || (bit_count == 26))  // Data ACK cycles
                begin
                  status[29] <= sda;  // SDA should be driven low for slave ACK
                end
              if ((bit_count == 18) & ctrl_reg[31]    // Reading and past first data ack
                  || (bit_count == 27))               // Past second data ack
                begin
                  timer <= t_su_sto;  // 4.0us from spec
                  rtn_state <= stop;
                  state <= spin;
                end
              else
                begin
                  if (bit_count != 17) read_data <= {read_data[6:0],sda};  // shift data in, MSB first
                  timer <= t_high;  // 4.0us from spec, but use 5.0 instead to meet cycle time
                  rtn_state <= clock_low;
                  state <= spin;
                end
            end
        end
      stop:
        begin
          // We get here twice for read cycles, once for writes.  On reads if
          // using repeated start we don't need to wait as long before asserting SDA
          // for start since t_su_sto has already elapsed (4.0us)
          float_sda <= 1;   // SDA will already be high in the case of repeated start
          if (sda)
            begin
              if (ctrl_reg[31]) // reading
                begin
                  if (wr_cyc)   // just finished sending subaddress
                    begin
                      if (ctrl_reg[30]) // repeated start
                        timer <= t_su_sta - t_su_sto;
                      else
                        timer <= t_su_sta;
                      rtn_state <= start;
                    end
                  else
                    begin
                      status[7:0] <= read_data;
                      status[28] <= 1;
                      timer <= t_su_sta;  // Setup to start is same as bus-free, 4.7us from spec
                      rtn_state <= idle;  // For writes we're all done
                    end
                  wr_cyc <= 0;
                  state <= spin;
                end
              else              // writing
                begin
                  status[28] <= 0;
                  timer <= t_su_sta;  // Setup to start is same as bus-free, 4.7us from spec
                  rtn_state <= idle;  // For writes we're all done
                  state <= spin;
                end
            end
        end
      spin:
        begin
          // stay in this state for requested time period then "return"
          if (timer > 0)
            begin
              timer <= timer - 1;
            end
          else
            begin
              state <= rtn_state;
            end
        end
    endcase
  end

endmodule

`default_nettype wire
