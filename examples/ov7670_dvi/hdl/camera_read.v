module camera_read(
	input wire p_clock,
	input wire vsync,
	input wire href,
	input wire [7:0] p_data,
	output reg [15:0] pixel_data,
	output reg pixel_valid,
	output reg frame_done,
	output [9:0] row,
	output [9:0] col
    );

	reg [7:0] first_byte, second_byte;
	reg [9:0] row_count, col_count;
	reg start_of_frame = 0;
	reg [7:0] data;

	assign row = row_count;
	assign col = col_count;

	reg [1:0] FSM_state = 0;
        reg pixel_half = 0;

	localparam WAIT_FRAME_START = 0;
	localparam ROW_CAPTURE = 1;

	always@(posedge p_clock)
	begin

	  case(FSM_state)

	  WAIT_FRAME_START: begin //wait for VSYNC
	     FSM_state <= (!vsync) ? ROW_CAPTURE : WAIT_FRAME_START;
	     frame_done <= 0;
	     pixel_half <= 0;
             start_of_frame <= 1;
             row_count <= 0;
             col_count <= 0;
	  end

	  ROW_CAPTURE: begin
	     FSM_state <= vsync ? WAIT_FRAME_START : ROW_CAPTURE;
	     frame_done <= vsync;
	     pixel_valid <= (href && pixel_half);
	     if (href) begin
                 if (start_of_frame) begin
                    if (!pixel_half) begin
                      first_byte <= p_data;
                      data <= p_data;
                    end
                    else begin
                      start_of_frame <= 0;
                      second_byte <= p_data;
                    end
                 end
	         if (pixel_half) pixel_data[7:0] <= p_data;
	         else pixel_data[15:8] <= p_data;
                 if (pixel_half) row_count <= row_count + 1;
	         pixel_half <= ~ pixel_half;
	     end else begin
               row_count <= 0;
               if (row_count != 0) col_count <= col_count + 1;
             end
	  end

	  endcase
	end
endmodule
