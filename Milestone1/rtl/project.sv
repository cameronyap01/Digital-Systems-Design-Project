/*
Copyright by Henry Ko and Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

// This is the top module (same as experiment4 from lab 5 - just module renamed to "project")
// It connects the UART, SRAM and VGA together.
// It gives access to the SRAM for UART and VGA
module project (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_N_I,         // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs

		/////// VGA interface                     ////////////
		output logic VGA_CLOCK_O,                 // VGA clock
		output logic VGA_HSYNC_O,                 // VGA H_SYNC
		output logic VGA_VSYNC_O,                 // VGA V_SYNC
		output logic VGA_BLANK_O,                 // VGA BLANK
		output logic VGA_SYNC_O,                  // VGA SYNC
		output logic[7:0] VGA_RED_O,              // VGA red
		output logic[7:0] VGA_GREEN_O,            // VGA green
		output logic[7:0] VGA_BLUE_O,             // VGA blue
		
		/////// SRAM Interface                    ////////////
		inout wire[15:0] SRAM_DATA_IO,            // SRAM data bus 16 bits
		output logic[19:0] SRAM_ADDRESS_O,        // SRAM address bus 18 bits
		output logic SRAM_UB_N_O,                 // SRAM high-byte data mask 
		output logic SRAM_LB_N_O,                 // SRAM low-byte data mask 
		output logic SRAM_WE_N_O,                 // SRAM write enable
		output logic SRAM_CE_N_O,                 // SRAM chip enable
		output logic SRAM_OE_N_O,                 // SRAM output logic enable
		
		/////// UART                              ////////////
		input logic UART_RX_I,                    // UART receive signal
		output logic UART_TX_O                    // UART transmit signal
);
	
logic resetn;

top_state_type top_state;
UPS_CSC_state_type CC_state;

// For Push button
logic [3:0] PB_pushed;

// For VGA SRAM interface
logic VGA_enable;
logic [17:0] VGA_base_address;
logic [17:0] VGA_SRAM_address;

// For SRAM
logic [17:0] SRAM_address;
logic [15:0] SRAM_write_data;
logic SRAM_we_n;
logic [15:0] SRAM_read_data;
logic SRAM_ready;

// For UART SRAM interface
logic UART_rx_enable;
logic UART_rx_initialize;
logic [17:0] UART_SRAM_address;
logic [15:0] UART_SRAM_write_data;
logic UART_SRAM_we_n;
logic [25:0] UART_timer;

// For Upsampling and Colour Space Correction drivers
logic [17:0] UPS_CSC_SRAM_address;
logic [15:0] UPS_CSC_SRAM_write_data;
logic [15:0] UPS;
logic UPS_CSC_SRAM_we_n;

logic [6:0] value_7_segment [7:0];

// Multiplier 1
logic [31:0] Mult1_op_1, Mult1_op_2, Mult1_result;
logic [63:0] Mult1_result_long;
assign Mult1_result_long = Mult1_op_1 * Mult1_op_2;
assign Mult1_result = Mult1_result_long[31:0];

// Multiplier 2
logic [31:0] Mult2_op_1, Mult2_op_2, Mult2_result;
logic [63:0] Mult2_result_long;
assign Mult2_result_long = Mult2_op_1 * Mult2_op_2;
assign Mult2_result = Mult2_result_long[31:0];

// Multiplier 3
logic [31:0] Mult3_op_1, Mult3_op_2, Mult3_result;
logic [63:0] Mult3_result_long;
assign Mult3_result_long = Mult3_op_1 * Mult3_op_2;
assign Mult3_result = Mult3_result_long[31:0];

// Flags
logic Req_f, Start_f, UPS_CSC_end_flag;

logic [15:0] Uin, Vin, Y, R, G, B, write_count, U_request_count; //make U and V prime 32 bit. add everything in then right shift 8 bits
logic [31:0] U_prime_odd, V_prime_odd, Rbuf, Gbuf, Bbuf, Yval;
logic [7:0] U_prime_even, V_prime_even, Row_counter;
logic [2:0] LO_count;

logic [17:0] Uaddress, Vaddress, Yaddress, RGBaddress;

logic [7:0] U[5:0];
logic [7:0] V[5:0];


// For error detection in UART
logic Frame_error;

// For disabling UART transmit
assign UART_TX_O = 1'b1;

assign resetn = ~SWITCH_I[17] && SRAM_ready;

// Push Button unit
PB_controller PB_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	.PB_signal(PUSH_BUTTON_N_I),	
	.PB_pushed(PB_pushed)
);

VGA_SRAM_interface VGA_unit (
	.Clock(CLOCK_50_I),
	.Resetn(resetn),
	.VGA_enable(VGA_enable),
   
	// For accessing SRAM
	.SRAM_base_address(VGA_base_address),
	.SRAM_address(VGA_SRAM_address),
	.SRAM_read_data(SRAM_read_data),
   
	// To VGA pins
	.VGA_CLOCK_O(VGA_CLOCK_O),
	.VGA_HSYNC_O(VGA_HSYNC_O),
	.VGA_VSYNC_O(VGA_VSYNC_O),
	.VGA_BLANK_O(VGA_BLANK_O),
	.VGA_SYNC_O(VGA_SYNC_O),
	.VGA_RED_O(VGA_RED_O),
	.VGA_GREEN_O(VGA_GREEN_O),
	.VGA_BLUE_O(VGA_BLUE_O)
);

// UART SRAM interface
UART_SRAM_interface UART_unit(
	.Clock(CLOCK_50_I),
	.Resetn(resetn), 
   
	.UART_RX_I(UART_RX_I),
	.Initialize(UART_rx_initialize),
	.Enable(UART_rx_enable),
   
	// For accessing SRAM
	.SRAM_address(UART_SRAM_address),
	.SRAM_write_data(UART_SRAM_write_data),
	.SRAM_we_n(UART_SRAM_we_n),
	.Frame_error(Frame_error)
);

// SRAM unit
SRAM_controller SRAM_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(~SWITCH_I[17]),
	.SRAM_address(SRAM_address),
	.SRAM_write_data(SRAM_write_data),
	.SRAM_we_n(SRAM_we_n),
	.SRAM_read_data(SRAM_read_data),		
	.SRAM_ready(SRAM_ready),
		
	// To the SRAM pins
	.SRAM_DATA_IO(SRAM_DATA_IO),
	.SRAM_ADDRESS_O(SRAM_ADDRESS_O[17:0]),
	.SRAM_UB_N_O(SRAM_UB_N_O),
	.SRAM_LB_N_O(SRAM_LB_N_O),
	.SRAM_WE_N_O(SRAM_WE_N_O),
	.SRAM_CE_N_O(SRAM_CE_N_O),
	.SRAM_OE_N_O(SRAM_OE_N_O)
);

assign SRAM_ADDRESS_O[19:18] = 2'b00;

always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		top_state <= S_IDLE;
		
		UART_rx_initialize <= 1'b0;
		UART_rx_enable <= 1'b0;
		UART_timer <= 26'd0;
		
		VGA_enable <= 1'b1;
	end else begin

		// By default the UART timer (used for timeout detection) is incremented
		// it will be synchronously reset to 0 under a few conditions (see below)
		UART_timer <= UART_timer + 26'd1;

		case (top_state)
		S_IDLE: begin
			VGA_enable <= 1'b1;  
			if (~UART_RX_I) begin
				// Start bit on the UART line is detected
				UART_rx_initialize <= 1'b1;
				UART_timer <= 26'd0;
				VGA_enable <= 1'b0;
				top_state <= S_UART_RX;
			end
		end

		S_UART_RX: begin
			// The two signals below (UART_rx_initialize/enable)
			// are used by the UART to SRAM interface for 
			// synchronization purposes (no need to change)
			UART_rx_initialize <= 1'b0;
			UART_rx_enable <= 1'b0;
			if (UART_rx_initialize == 1'b1) 
				UART_rx_enable <= 1'b1;

			// UART timer resets itself every time two bytes have been received
			// by the UART receiver and a write in the external SRAM can be done
			if (~UART_SRAM_we_n) 
				UART_timer <= 26'd0;

			// Timeout for 1 sec on UART (detect if file transmission is finished)
			if (UART_timer == 26'd49999999) begin
				top_state <= S_UPS_CSC_TOP;
				UART_timer <= 26'd0;
			end
		end
		
		S_UPS_CSC_TOP: begin
			// transition to VGA output state
			if (UPS_CSC_end_flag == 1'b1)
				top_state <= S_VGA_Output;

		end

		S_VGA_Output: begin
			top_state <= S_IDLE;
		end
		default: top_state <= S_IDLE;

		endcase
	end
end

always_ff @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		CC_state <= S_CC_IDLE;
		UPS_CSC_end_flag <= 1'b0;
		Start_f <= 1'b1;
		Req_f <= 1'b1;
		Row_counter <= 8'd0;
		Yaddress <= 18'd0;
		Uaddress <= 18'd38400;
		Vaddress <= 18'd57600;
		RGBaddress <= 18'd146944;
		Yaddress <= 18'd0;
		Uaddress <= 18'd38400;
		Vaddress <= 18'd57600;
		RGBaddress <= 18'd146944;
		
	end else begin
	
		case (CC_state)
		
		S_CC_IDLE: begin
			if (top_state == S_UPS_CSC_TOP) begin
				Start_f <= 1'b1; // Flag to indicate the first common case
				Req_f <= 1'b1; // Flag to make requests for U and V data

				write_count <= 16'd0;
				LO_count <= 3'd0;
				UPS_CSC_SRAM_we_n <= 1'b1;
				U_request_count <= 16'd0;
				if (Row_counter < 8'd240) 
					CC_state <= S_Start_0;
				else 
					UPS_CSC_end_flag <= 1'b1;
				
			end
		end
		
		
		S_Start_0: begin
			UPS_CSC_SRAM_address <= Uaddress;
			Uaddress <= Uaddress + 18'd1;
			U_request_count <= U_request_count + 16'd1;
			
			CC_state <= S_Start_1;
		end

		
		S_Start_1: begin
			UPS_CSC_SRAM_address <= Vaddress;
			Vaddress <= Vaddress + 18'd1;
			
			CC_state <= S_Start_2;
		end
		
		
		S_Start_2: begin
			UPS_CSC_SRAM_address <= Uaddress;
			Uaddress <= Uaddress + 18'd1;
			U_request_count <= U_request_count + 16'd1;
			
			CC_state <= S_Start_3;
		end

		
		S_Start_3: begin
			UPS_CSC_SRAM_address <= Vaddress;
			Vaddress <= Vaddress + 18'd1;
			Uin <= SRAM_read_data;
			
			U[0] <= SRAM_read_data[7:0];
			U[1] <= SRAM_read_data[15:8];
			U[2] <= SRAM_read_data[15:8];
			U[3] <= SRAM_read_data[15:8];
			U[4] <= SRAM_read_data[15:8];
			U[5] <= SRAM_read_data[15:8];
			
			CC_state <= S_Start_4;
		end
		
		
		S_Start_4: begin
			Vin <= SRAM_read_data;
			V[0] <= SRAM_read_data[7:0];
			V[1] <= SRAM_read_data[15:8];
			V[2] <= SRAM_read_data[15:8];
			V[3] <= SRAM_read_data[15:8];
			V[4] <= SRAM_read_data[15:8];
			V[5] <= SRAM_read_data[15:8];
			
			CC_state <= S_Start_5;
		end
		
		
		S_Start_5: begin
			Uin <= SRAM_read_data;
			U[0] <= SRAM_read_data[15:8];
			U[1] <= U[0];
			U[2] <= U[1];
			U[3] <= U[2];
			U[4] <= U[3];
			U[5] <= U[4];
		
			CC_state <= S_Start_6;
		end
		
	
		S_Start_6: begin
			UPS_CSC_SRAM_address <= Yaddress;
			Yaddress <= Yaddress + 18'd1;
			Vin <= SRAM_read_data;
			
			V[0] <= SRAM_read_data[15:8];
			V[1] <= V[0];
			V[2] <= V[1];
			V[3] <= V[2];
			V[4] <= V[3];
			V[5] <= V[4];
			
			CC_state <= S_Start_7;
		end
		
		
		S_Start_7: begin
			U[0] <= Uin[7:0];
			U[1] <= U[0];
			U[2] <= U[1];
			U[3] <= U[2];
			U[4] <= U[3];
			U[5] <= U[4];
		
			CC_state <= S_CC_0;
		end
		
		
		S_CC_0: begin
			if (Start_f == 1'b0) begin
				write_count <= write_count + 16'd1;
				UPS_CSC_SRAM_we_n <= ~UPS_CSC_SRAM_we_n;
				UPS_CSC_SRAM_address <= RGBaddress;
				RGBaddress <= RGBaddress + 18'd1;
				UPS_CSC_SRAM_write_data <= {R[15:8], G[15:8]};
				Rbuf <= $signed(Rbuf + Yval) >>> 16;
				Gbuf <= $signed(Yval - Mult1_result - Mult2_result) >>> 16;
				Bbuf <= $signed(Yval + Mult3_result) >>> 16;
			end
			
			if (Req_f == 1'b0) begin // After request is made for new V data, Req_f is set to 0. When Req_f is 0 this indicates we are receiving new data
				Vin <= SRAM_read_data;
				V[0] <= SRAM_read_data[15:8];
				V[1] <= V[0];
				V[2] <= V[1];
				V[3] <= V[2];
				V[4] <= V[3];
				V[5] <= V[4];
			end else begin // Req_f is set to 1 when new V data is not being requested
				V[0] <= Vin[7:0];
				V[1] <= V[0];
				V[2] <= V[1];
				V[3] <= V[2];
				V[4] <= V[3];
				V[5] <= V[4];
			end
			
			Mult1_op_1 <= 16'd21;
			Mult1_op_2 <= U[5];
			
			Mult2_op_1 <= 16'd52;
			Mult2_op_2 <= U[4];
			
			Mult3_op_1 <= 16'd159;
			Mult3_op_2 <= U[3];
			
			//shift back all prime assignments by 1 state
			
			U_prime_even <= U[3];
			
			CC_state <= S_CC_1;
		end
		
		
		S_CC_1: begin
			if (Start_f == 1'b0) begin
				write_count <= write_count + 16'd1;
				UPS_CSC_SRAM_address <= RGBaddress;
				RGBaddress <= RGBaddress + 18'd1;
				if ($signed(Rbuf) < 0) begin
					R[7:0] <= 8'd0;
					UPS_CSC_SRAM_write_data <= {B[15:8], 8'd0};
				end else if ($signed(Rbuf) > 255) begin
					R[7:0] <= 8'd255;
					UPS_CSC_SRAM_write_data <= {B[15:8], 8'd255};
				end else begin
					R[7:0] <= Rbuf[7:0];
					UPS_CSC_SRAM_write_data <= {B[15:8], Rbuf[7:0]};
				end	
				
				if ($signed(Gbuf) < 0)
					G[7:0] <= 8'd0;
				else if ($signed(Gbuf) > 255)
					G[7:0] <= 8'd255;
				else
					G[7:0] <= Gbuf[7:0];
				
				if ($signed(Bbuf) < 0)
					B[7:0] <= 8'd0;
				else if ($signed(Bbuf) > 255)
					B[7:0] <= 8'd255;
				else
					B[7:0] <= Bbuf[7:0];
			end
			
			Y <= SRAM_read_data;

			Mult1_op_1 <= 16'd159;
			Mult1_op_2 <= U[2];
			
			Mult2_op_1 <= 16'd52;
			Mult2_op_2 <= U[1];
			
			Mult3_op_1 <= 16'd21;
			Mult3_op_2 <= U[0];
			
			U_prime_odd <= Mult1_result - Mult2_result + Mult3_result; //dont shift in addition shift when you go to do final sum
			
			V_prime_even <= V[3];
			
			CC_state <= S_CC_2;
		end
		
		
		S_CC_2: begin
			if (Start_f == 1'b0) begin
				write_count <= write_count + 16'd1;
				UPS_CSC_SRAM_address <= RGBaddress;
				RGBaddress <= RGBaddress + 18'd1;
				UPS_CSC_SRAM_write_data <= {G[7:0], B[7:0]};
			end
			
			Mult1_op_1 <= 16'd21;
			Mult1_op_2 <= V[5];
			
			Mult2_op_1 <= 16'd52;
			Mult2_op_2 <= V[4];
			
			Mult3_op_1 <= 16'd159;
			Mult3_op_2 <= V[3];
			
			U_prime_odd <= (U_prime_odd + Mult1_result - Mult2_result + Mult3_result + 32'd128) >>> 8;
			
			
			CC_state <= S_CC_3;
		end
		
		
		S_CC_3: begin
			if (Start_f == 1'b0) begin
				UPS_CSC_SRAM_we_n <= ~UPS_CSC_SRAM_we_n;
			end
			else Start_f <= 1'b0;
			
			Mult1_op_1 <= 16'd159;
			Mult1_op_2 <= V[2];
			
			Mult2_op_1 <= 16'd52;
			Mult2_op_2 <= V[1];
			
			Mult3_op_1 <= 16'd21;
			Mult3_op_2 <= V[0];
			
			V_prime_odd <= Mult1_result - Mult2_result + Mult3_result;
			
			CC_state <= S_CC_4;
		end
		
		
		S_CC_4: begin
			if (Req_f == 1'b1) begin
				UPS_CSC_SRAM_address <= Uaddress;
				Uaddress <= Uaddress + 18'd1;
				U_request_count <= U_request_count + 16'd1;
			end
			
			Mult1_op_1 <= Y[15:8] - 8'd16;
			Mult1_op_2 <= 32'd76284;
			
			Mult2_op_1 <= V_prime_even - 8'd128;
			Mult2_op_2 <= 32'd104595;
			
			V_prime_odd <= (V_prime_odd + Mult1_result - Mult2_result + Mult3_result + 32'd128) >>> 8;
			
			CC_state <= S_CC_5;
		end
		
		
		S_CC_5: begin
			if (Req_f == 1'b1) begin
				UPS_CSC_SRAM_address <= Vaddress;
				Vaddress <= Vaddress + 18'd1;
				Req_f <= 1'b0;
			end
			else Req_f <= 1'b1; // Set Req_f to 1 to request data in next common case and to use old U and V data stored in Uin and Vin
			
			Mult1_op_1 <= U_prime_even - 8'd128;
			Mult1_op_2 <= 32'd25624;
			
			Mult2_op_1 <= V_prime_even - 8'd128;
			Mult2_op_2 <= 32'd53281;
			
			Mult3_op_1 <= U_prime_even - 8'd128;
			Mult3_op_2 <= 32'd132251;
			
			Yval <= Mult1_result;
			
			Rbuf <= Mult2_result;
			
			if ((U_request_count == 16'd80) && (Req_f == 1'b0)) CC_state <= S_LO_6;
			else CC_state <= S_CC_6;
		end
		
		
		S_CC_6: begin
			UPS_CSC_SRAM_address <= Yaddress;
			Yaddress <= Yaddress + 18'd1;
			
			Mult1_op_1 <= Y[7:0] - 8'd16;
			Mult1_op_2 <= 32'd76284;
			
			Mult2_op_1 <= V_prime_odd - 32'd128;
			Mult2_op_2 <= 32'd104595;
			
			Rbuf <= $signed(Rbuf + Yval) >>> 16;
			
			Gbuf <= $signed(Yval - Mult1_result - Mult2_result) >>> 16;
			
			Bbuf <= $signed(Yval + Mult3_result) >>> 16;
		
			
			CC_state <= S_CC_7;
		end
		
		
		S_CC_7: begin
			if (Req_f == 1'b0) begin
				Uin <= SRAM_read_data;
				U[0] <= SRAM_read_data[15:8];
				U[1] <= U[0];
				U[2] <= U[1];
				U[3] <= U[2];
				U[4] <= U[3];
				U[5] <= U[4];
				
			end
			else begin
				U[0] <= Uin[7:0];
				U[1] <= U[0];
				U[2] <= U[1];
				U[3] <= U[2];
				U[4] <= U[3];
				U[5] <= U[4];
			end
			
			Mult1_op_1 <= U_prime_odd - 32'd128;
			Mult1_op_2 <= 32'd25624;
			
			Mult2_op_1 <= V_prime_odd - 32'd128;
			Mult2_op_2 <= 32'd53281;
			
			Mult3_op_1 <= U_prime_odd - 32'd128;
			Mult3_op_2 <= 32'd132251;
			
			if ($signed(Rbuf) < 0)
				R[15:8] <= 8'd0;
			else if ($signed(Rbuf) > 255)
				R[15:8] <= 8'd255;
			else
				R[15:8] <= Rbuf[7:0];
			
			if ($signed(Gbuf) < 0)
				G[15:8] <= 8'd0;
			else if ($signed(Gbuf) > 255)
				G[15:8] <= 8'd255;
			else
				G[15:8] <= Gbuf[7:0];
			
			if ($signed(Bbuf) < 0)
				B[15:8] <= 8'd0;
			else if ($signed(Bbuf) > 255)
				B[15:8] <= 8'd255;
			else
				B[15:8] <= Bbuf[7:0];
			
			Yval <= Mult1_result;
			
			Rbuf <= Mult2_result;
			
			CC_state <= S_CC_0;
		end
		
		
		S_LO_0: begin

			write_count <= write_count + 16'd1;
			UPS_CSC_SRAM_we_n <= ~UPS_CSC_SRAM_we_n;
			UPS_CSC_SRAM_address <= RGBaddress;
			RGBaddress <= RGBaddress + 18'd1;
			UPS_CSC_SRAM_write_data <= {R[15:8], G[15:8]};
			Rbuf <= $signed(Rbuf + Yval) >>> 16;
			Gbuf <= $signed(Yval - Mult1_result - Mult2_result) >>> 16;
			Bbuf <= $signed(Yval + Mult3_result) >>> 16;
		
			V[0] <= Vin[7:0];
			V[1] <= V[0];
			V[2] <= V[1];
			V[3] <= V[2];
			V[4] <= V[3];
			V[5] <= V[4];

			Mult1_op_1 <= 16'd21;
			Mult1_op_2 <= U[5];
			
			Mult2_op_1 <= 16'd52;
			Mult2_op_2 <= U[4];
			
			Mult3_op_1 <= 16'd159;
			Mult3_op_2 <= U[3];
			
			//shift back all prime assignments by 1 state
			
			U_prime_even <= U[3];
			
			CC_state <= S_LO_1;
		end
		
		
		S_LO_1: begin

			write_count <= write_count + 16'd1;
			UPS_CSC_SRAM_address <= RGBaddress;
			RGBaddress <= RGBaddress + 18'd1;
			if ($signed(Rbuf) < 0) begin
				R[7:0] <= 8'd0;
				UPS_CSC_SRAM_write_data <= {B[15:8], 8'd0};
			end else if ($signed(Rbuf) > 255) begin
				R[7:0] <= 8'd255;
				UPS_CSC_SRAM_write_data <= {B[15:8], 8'd255};
			end else begin
				R[7:0] <= Rbuf[7:0];
				UPS_CSC_SRAM_write_data <= {B[15:8], Rbuf[7:0]};
			end	
			
			if ($signed(Gbuf) < 0)
				G[7:0] <= 8'd0;
			else if ($signed(Gbuf) > 255)
				G[7:0] <= 8'd255;
			else
				G[7:0] <= Gbuf[7:0];
			
			if ($signed(Bbuf) < 0)
				B[7:0] <= 8'd0;
			else if ($signed(Bbuf) > 255)
				B[7:0] <= 8'd255;
			else
				B[7:0] <= Bbuf[7:0];

			
			Y <= SRAM_read_data;

			Mult1_op_1 <= 16'd159;
			Mult1_op_2 <= U[2];
			
			Mult2_op_1 <= 16'd52;
			Mult2_op_2 <= U[1];
			
			Mult3_op_1 <= 16'd21;
			Mult3_op_2 <= U[0];
			
			U_prime_odd <= Mult1_result - Mult2_result + Mult3_result; //dont shift in addition shift when you go to do final sum
			
			V_prime_even <= V[3];
			
			CC_state <= S_LO_2;
		end
		
		
		S_LO_2: begin

			write_count <= write_count + 16'd1;
			UPS_CSC_SRAM_address <= RGBaddress;
			RGBaddress <= RGBaddress + 18'd1;
			UPS_CSC_SRAM_write_data <= {G[7:0], B[7:0]};
			
			Mult1_op_1 <= 16'd21;
			Mult1_op_2 <= V[5];
			
			Mult2_op_1 <= 16'd52;
			Mult2_op_2 <= V[4];
			
			Mult3_op_1 <= 16'd159;
			Mult3_op_2 <= V[3];
			
			U_prime_odd <= (U_prime_odd + Mult1_result - Mult2_result + Mult3_result + 32'd128) >>> 8;
			
			
			CC_state <= S_LO_3;
		end
		
		
		S_LO_3: begin
			UPS_CSC_SRAM_we_n <= ~UPS_CSC_SRAM_we_n; //pay attention to this
			
			Mult1_op_1 <= 16'd159;
			Mult1_op_2 <= V[2];
			
			Mult2_op_1 <= 16'd52;
			Mult2_op_2 <= V[1];
			
			Mult3_op_1 <= 16'd21;
			Mult3_op_2 <= V[0];
			
			V_prime_odd <= Mult1_result - Mult2_result + Mult3_result;
			
			CC_state <= S_LO_4;
		end
		
		
		S_LO_4: begin
			
			Mult1_op_1 <= Y[15:8] - 8'd16;
			Mult1_op_2 <= 32'd76284;
			
			Mult2_op_1 <= V_prime_even - 8'd128;
			Mult2_op_2 <= 32'd104595;
			
			V_prime_odd <= (V_prime_odd + Mult1_result - Mult2_result + Mult3_result + 32'd128) >>> 8;
			
			CC_state <= S_LO_5;
		end
		
		
		S_LO_5: begin
			Mult1_op_1 <= U_prime_even - 8'd128;
			Mult1_op_2 <= 32'd25624;
			
			Mult2_op_1 <= V_prime_even - 8'd128;
			Mult2_op_2 <= 32'd53281;
			
			Mult3_op_1 <= U_prime_even - 8'd128;
			Mult3_op_2 <= 32'd132251;
			
			Yval <= Mult1_result;
			
			Rbuf <= Mult2_result;
			
			
			CC_state <= S_LO_6;
		end
		
		
		S_LO_6: begin
			if (LO_count < 4) begin
				UPS_CSC_SRAM_address <= Yaddress;
				Yaddress <= Yaddress + 18'd1;
			end

			Mult1_op_1 <= Y[7:0] - 8'd16;
			Mult1_op_2 <= 32'd76284;
			
			Mult2_op_1 <= V_prime_odd - 32'd128;
			Mult2_op_2 <= 32'd104595;
			
			Rbuf <= $signed(Rbuf + Yval) >>> 16;
			
			Gbuf <= $signed(Yval - Mult1_result - Mult2_result) >>> 16;
			
			Bbuf <= $signed(Yval + Mult3_result) >>> 16;
		
			
			CC_state <= S_LO_7;
		end
		
		
		S_LO_7: begin

			if (LO_count < 4) begin
				U[0] <= Uin[7:0];
				U[1] <= U[0];
				U[2] <= U[1];
				U[3] <= U[2];
				U[4] <= U[3];
				U[5] <= U[4];
				CC_state <= S_LO_0;
			end
			else 
				CC_state <= S_LOF_0;
			LO_count <= LO_count + 3'd1;
			
			Mult1_op_1 <= U_prime_odd - 32'd128;
			Mult1_op_2 <= 32'd25624;
			
			Mult2_op_1 <= V_prime_odd - 32'd128;
			Mult2_op_2 <= 32'd53281;
			
			Mult3_op_1 <= U_prime_odd - 32'd128;
			Mult3_op_2 <= 32'd132251;
			
			if ($signed(Rbuf) < 0)
				R[15:8] <= 8'd0;
			else if ($signed(Rbuf) >= 255)
				R[15:8] <= 8'd255;
			else
				R[15:8] <= Rbuf[7:0];
			
			if ($signed(Gbuf) < 0)
				G[15:8] <= 8'd0;
			else if ($signed(Gbuf) > 255)
				G[15:8] <= 8'd255;
			else
				G[15:8] <= Gbuf[7:0];
			
			if ($signed(Bbuf) < 0)
				B[15:8] <= 8'd0;
			else if ($signed(Bbuf) > 255)
				B[15:8] <= 8'd255;
			else
				B[15:8] <= Bbuf[7:0];
			
			Yval <= Mult1_result;
			
			Rbuf <= Mult2_result;
		end
		
		S_LOF_0: begin
			write_count <= write_count + 16'd1;
			UPS_CSC_SRAM_we_n <= ~UPS_CSC_SRAM_we_n;
			UPS_CSC_SRAM_address <= RGBaddress;
			RGBaddress <= RGBaddress + 18'd1;
			UPS_CSC_SRAM_write_data <= {R[15:8], G[15:8]};
			Rbuf <= $signed(Rbuf + Yval) >>> 16;
			Gbuf <= $signed(Yval - Mult1_result - Mult2_result) >>> 16;
			Bbuf <= $signed(Yval + Mult3_result) >>> 16;
			
			CC_state <= S_LOF_1;
		end
		
		
		S_LOF_1: begin
			write_count <= write_count + 16'd1;
			UPS_CSC_SRAM_address <= RGBaddress;
			RGBaddress <= RGBaddress + 18'd1;
			if ($signed(Rbuf) < 0) begin
				R[7:0] <= 8'd0;
				UPS_CSC_SRAM_write_data <= {B[15:8], 8'd0};
			end else if ($signed(Rbuf) > 255) begin
				R[7:0] <= 8'd255;
				UPS_CSC_SRAM_write_data <= {B[15:8], 8'd255};
			end else begin
				R[7:0] <= Rbuf[7:0];
				UPS_CSC_SRAM_write_data <= {B[15:8], Rbuf[7:0]};
			end	
			
			if ($signed(Gbuf) < 0)
				G[7:0] <= 8'd0;
			else if ($signed(Gbuf) > 255)
				G[7:0] <= 8'd255;
			else
				G[7:0] <= Gbuf[7:0];
			
			if ($signed(Bbuf) < 0)
				B[7:0] <= 8'd0;
			else if ($signed(Bbuf) > 255)
				B[7:0] <= 8'd255;
			else
				B[7:0] <= Bbuf[7:0];
		
			CC_state <= S_LOF_2;
		end
		
		
		S_LOF_2: begin
			write_count <= write_count + 16'd1;
			UPS_CSC_SRAM_address <= RGBaddress;
			RGBaddress <= RGBaddress + 18'd1;
			UPS_CSC_SRAM_write_data <= {G[7:0], B[7:0]};
		
			Row_counter = Row_counter + 8'd1;
			CC_state <= S_CC_IDLE;
		end
		
	
		default: CC_state <= S_CC_IDLE;
		
		endcase
	end
end

// for this design we assume that the RGB data starts at location 0 in the external SRAM
// if the memory layout is different, this value should be adjusted 
// to match the starting address of the raw RGB data segment
assign VGA_base_address = 18'd146944;

// Give access to SRAM for UART and VGA at appropriate time
always_comb begin

	if (top_state == S_UART_RX) begin
		SRAM_address = UART_SRAM_address;
		SRAM_write_data = UART_SRAM_write_data;
		SRAM_we_n = UART_SRAM_we_n;
	end
	else if (top_state == S_UPS_CSC_TOP) begin
		SRAM_address = UPS_CSC_SRAM_address;
		SRAM_write_data = UPS_CSC_SRAM_write_data;
		SRAM_we_n = UPS_CSC_SRAM_we_n;
	end
	else begin //this currently holds VGA conditions need to update
		SRAM_address = VGA_SRAM_address;
		SRAM_write_data = 16'd0;
		SRAM_we_n = 1'b1;
	end
end


//SRAM_address = (top_state == S_UART_RX) ? UART_SRAM_address : VGA_SRAM_address;
//
//SRAM_write_data = (top_state == S_UART_RX) ? UART_SRAM_write_data : 16'd0;
//
//SRAM_we_n = (top_state == S_UART_RX) ? UART_SRAM_we_n : 1'b1;


// 7 segment displays
convert_hex_to_seven_segment unit7 (
	.hex_value(SRAM_read_data[15:12]), 
	.converted_value(value_7_segment[7])
);

convert_hex_to_seven_segment unit6 (
	.hex_value(SRAM_read_data[11:8]), 
	.converted_value(value_7_segment[6])
);

convert_hex_to_seven_segment unit5 (
	.hex_value(SRAM_read_data[7:4]), 
	.converted_value(value_7_segment[5])
);

convert_hex_to_seven_segment unit4 (
	.hex_value(SRAM_read_data[3:0]), 
	.converted_value(value_7_segment[4])
);

convert_hex_to_seven_segment unit3 (
	.hex_value({2'b00, SRAM_address[17:16]}), 
	.converted_value(value_7_segment[3])
);

convert_hex_to_seven_segment unit2 (
	.hex_value(SRAM_address[15:12]), 
	.converted_value(value_7_segment[2])
);

convert_hex_to_seven_segment unit1 (
	.hex_value(SRAM_address[11:8]), 
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(SRAM_address[7:4]), 
	.converted_value(value_7_segment[0])
);

assign   
   SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
   SEVEN_SEGMENT_N_O[1] = value_7_segment[1],
   SEVEN_SEGMENT_N_O[2] = value_7_segment[2],
   SEVEN_SEGMENT_N_O[3] = value_7_segment[3],
   SEVEN_SEGMENT_N_O[4] = value_7_segment[4],
   SEVEN_SEGMENT_N_O[5] = value_7_segment[5],
   SEVEN_SEGMENT_N_O[6] = value_7_segment[6],
   SEVEN_SEGMENT_N_O[7] = value_7_segment[7];

assign LED_GREEN_O = {resetn, VGA_enable, ~SRAM_we_n, Frame_error, UART_rx_initialize, PB_pushed};

endmodule
