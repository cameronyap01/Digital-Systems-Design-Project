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
IDCT_state_type IDCT_state;

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



logic [6:0] value_7_segment [7:0];

// UPS CSC Multiplier 1
logic [31:0] Mult1_op_1, Mult1_op_2, Mult1_result;
logic [63:0] Mult1_result_long;
assign Mult1_result_long = Mult1_op_1 * Mult1_op_2;
assign Mult1_result = Mult1_result_long[31:0];

// UPS CSC Multiplier 2
logic [31:0] Mult2_op_1, Mult2_op_2, Mult2_result;
logic [63:0] Mult2_result_long;
assign Mult2_result_long = Mult2_op_1 * Mult2_op_2;
assign Mult2_result = Mult2_result_long[31:0];

// UPS CSC Multiplier 3
logic [31:0] Mult3_op_1, Mult3_op_2, Mult3_result;
logic [63:0] Mult3_result_long;
assign Mult3_result_long = Mult3_op_1 * Mult3_op_2;
assign Mult3_result = Mult3_result_long[31:0];

// IDCT Multiplier 1
logic [31:0] IDCT_Mult1_op_1, IDCT_Mult1_op_2, IDCT_Mult1_result;
logic [63:0] IDCT_Mult1_result_long;
assign IDCT_Mult1_result_long = IDCT_Mult1_op_1 * IDCT_Mult1_op_2;
assign IDCT_Mult1_result = IDCT_Mult1_result_long[31:0];

// IDCT Multiplier 2
logic [31:0] IDCT_Mult2_op_1, IDCT_Mult2_op_2, IDCT_Mult2_result;
logic [63:0] IDCT_Mult2_result_long;
assign IDCT_Mult2_result_long = IDCT_Mult2_op_1 * IDCT_Mult2_op_2;
assign IDCT_Mult2_result = IDCT_Mult2_result_long[31:0];

// Flags for M1
logic Req_f, Start_f, UPS_CSC_end_flag;

// Resources for M1
logic [15:0] Uin, Vin, Y, R, G, B, write_count, U_request_count; //make U and V prime 32 bit. add everything in then right shift 8 bits
logic [31:0] U_prime_odd, V_prime_odd, Rbuf, Gbuf, Bbuf, Yval;
logic [7:0] U_prime_even, V_prime_even, Row_counter;
logic [2:0] LO_count;

// Upsampling and Colour Space Correction drivers for M1
logic [17:0] UPS_CSC_SRAM_address;
logic [15:0] UPS_CSC_SRAM_write_data;
logic UPS_CSC_SRAM_we_n;


logic [17:0] Uaddress, Vaddress, Yaddress, RGBaddress;

logic [7:0] U[5:0];
logic [7:0] V[5:0];

// Counters for M2
logic [5:0] Sp_counter, S_counter, Sp_col_block_counter, S_col_block_counter, S_state_counter, max_column_blocks;
logic [4:0] Sp_row_block_counter, S_row_block_counter, max_row_blocks;
logic [3:0] S_mult_counter;
logic [1:0] S_lastreceive_counter;
logic [7:0] Sp_RA, S_RA; 
logic [8:0] Sp_CA, S_CA;

// IDCT SRAM Drivers for M2
logic [17:0] IDCT_SRAM_address;
logic [15:0] IDCT_SRAM_write_data;
logic IDCT_SRAM_we_n;


// Flags for M2
logic IDCT_end_flag, write_s_f, fetch_sp_f;
logic [1:0] UV_transition;

logic [17:0] Sp_read_address, S_write_address, read_address_offset, write_address_offset;

// Buffers for M2
logic [15:0] Sp_data_buf, C_data_buf;
logic [31:0] TS_buf_0, TS_buf_1, Calc_buf_0, Calc_buf_1, Calc_buf_2, Calc_buf_3;


// DP-RAM Inputs and Outputs for M2
logic[6:0] R0_address_0, R0_address_1, R1_address_0, R1_address_1, C_address, Sp_address, T_address, S_address;
logic[31:0] R0_data_in_0, R0_data_in_1, R1_data_in_0, R1_data_in_1, R0_data_out_0, R0_data_out_1, R1_data_out_0, R1_data_out_1;
logic R0_wren_0, R0_wren_1, R1_wren_0, R1_wren_1;

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

dual_port_RAM #(.RAMmif("../rtl/RAM0_init.mif")) RAM_inst0 (
	.address_a ( R0_address_0 ),
	.address_b ( R0_address_1 ),
	.clock ( CLOCK_50_I ),
	.data_a ( R0_data_in_0 ),
	.data_b ( R0_data_in_1 ),
	.wren_a ( R0_wren_0 ),
	.wren_b ( R0_wren_1 ),
	.q_a ( R0_data_out_0 ),
	.q_b ( R0_data_out_1 )
	);

dual_port_RAM #(.RAMmif("../rtl/RAM1_init.mif")) RAM_inst1 (
	.address_a ( R1_address_0 ),
	.address_b ( R1_address_1 ),
	.clock ( CLOCK_50_I ),
	.data_a ( R1_data_in_0 ),
	.data_b ( R1_data_in_1 ),
	.wren_a ( R1_wren_0 ),
	.wren_b ( R1_wren_1 ),
	.q_a ( R1_data_out_0 ),
	.q_b ( R1_data_out_1 )
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
				top_state <= S_IDCT_TOP;
				UART_timer <= 26'd0;
			end
		end
		
		S_IDCT_TOP: begin
			if (IDCT_end_flag == 1'b1)
				top_state <= S_UPS_CSC_TOP;
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
	
		IDCT_state <= S_IDCT_IDLE;
		IDCT_end_flag <= 1'b0;
		
		Sp_counter <= 6'd0;
		Sp_col_block_counter <= 6'd0;
		Sp_row_block_counter <= 5'd0;
		S_counter <= 5'd0;
		S_col_block_counter <= 6'd0;
		S_row_block_counter <= 5'd0;
		write_s_f <= 1'd1;
		UV_transition <=2'd0;

		
	end else begin
	
		case (IDCT_state)
		
		S_IDCT_IDLE: begin
			if (top_state == S_IDCT_TOP) begin
				IDCT_SRAM_we_n <= 1'b1;
				Sp_data_buf <= 16'd0;
				TS_buf_0 <= 32'd0;
				Calc_buf_0 <= 32'd0;
				Calc_buf_1 <= 32'd0;
				Calc_buf_2 <= 32'd0;
				Calc_buf_3 <= 32'd0;
				C_address <= 7'd64;
				Sp_address <= 7'd0;
				T_address <= 7'd0;
				if (UV_transition < 2'd3)
					IDCT_state <= S_IDCT_SLI_0;
				else
					IDCT_end_flag <= 1'd1;
			end
		end
		
		S_IDCT_SLI_0: begin
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;
			
			Sp_counter <= Sp_counter + 6'd8;
			
			IDCT_state <= S_IDCT_SLI_1;
		end
		
		S_IDCT_SLI_1: begin
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;
			
			Sp_counter <= Sp_counter - 6'd7;
			
			IDCT_state <= S_IDCT_SLI_2;
		end
		
		S_IDCT_SLI_2: begin
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;
			
			Sp_counter <= Sp_counter + 6'd8;
			
			IDCT_state <= S_IDCT_S_0;
		end
		
		S_IDCT_S_0: begin
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;
			R0_wren_0 <= 1'd0;
			Sp_data_buf <= SRAM_read_data;
			if (Sp_counter == 6'd63) begin
				Sp_counter <= 6'd0;
				if (Sp_col_block_counter[2:0] == 3'b111) begin
					Sp_col_block_counter <= 6'd0;
					Sp_row_block_counter <= Sp_row_block_counter + 5'd1;
				end
				else
					Sp_col_block_counter <= Sp_col_block_counter + 6'd1;
				IDCT_state <= S_IDCT_SLO_0;
			end
			else if (Sp_counter[3:0] == 4'd15) begin
				Sp_counter <= Sp_counter + 6'd1;
				IDCT_state <= S_IDCT_S_1;
			end
			else begin
				Sp_counter <= Sp_counter - 6'd7;
				IDCT_state <= S_IDCT_S_1;
			end
		end
		
		S_IDCT_S_1: begin
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;
			Sp_counter <= Sp_counter + 6'd8;
			R0_wren_0 <= 1'd1;
			if (Sp_counter == 6'd2)begin
				R0_address_0 <= 7'd0; // denotes our first write of sprime data into DRAM
				Sp_address <= Sp_address + 7'd1;
			end
			else begin
				R0_address_0 <= Sp_address; // Sp_address is used to keep track of where Sprime is being written in R0
				Sp_address <= Sp_address + 7'd1; // iterate Sp_address to make sure we write to the right position next time we write
			end
			R0_data_in_0 <= {Sp_data_buf, SRAM_read_data};
			
			
			IDCT_state <= S_IDCT_S_0;
		end
		
		
		S_IDCT_SLO_0: begin
			R0_wren_0 <= 1'd1;
			R0_address_0 <= Sp_address;
			Sp_address <= Sp_address + 7'd1;
			R0_data_in_0 <= {Sp_data_buf, SRAM_read_data};

			IDCT_state <= S_IDCT_SLO_1;
		end
		
		S_IDCT_SLO_1: begin
			Sp_data_buf <= SRAM_read_data;
			IDCT_state <= S_IDCT_SLO_2;
		end
		
		S_IDCT_SLO_2: begin
			R0_address_0 <= Sp_address;
			Sp_address <= 7'd0; // resets Sp_address to 0 in order to prepare to read Sprime data from R0
			R0_data_in_0 <= {Sp_data_buf, SRAM_read_data};
			
			IDCT_state <= S_IDCT_CALCT_LI0;
		end
		
		S_IDCT_CALCT_LI0: begin
			R0_wren_0 <= 1'd0;
			R0_wren_1 <= 1'd0;
			R1_wren_0 <= 1'd0;
			R1_wren_1 <= 1'd0;
			R0_address_0 <= C_address; // C_address keeps track of where we're reading C data from R0
			R0_address_1 <= Sp_address; //Sp_address keeps track of where we're reading S data from R0
			S_counter <= 6'd0;
			
			if (write_s_f == 1'd0) begin
				R1_address_1 <= S_address;
				S_address <= S_address + 7'd1;
			end

			IDCT_state <= S_IDCT_CALCT_LI1;
			
		end
		
		S_IDCT_CALCT_LI1: begin //LI0
			C_address <= C_address + 7'd4;
			Sp_address <= Sp_address + 7'd1;
			if (write_s_f == 1'd0) begin
				R1_address_1 <= S_address;
				S_address <= S_address + 7'd1;
			end
			IDCT_state <= S_IDCT_CALCT_LI2;
		end
		
		S_IDCT_CALCT_LI2: begin // LI1

			R0_address_0 <= C_address;
			R0_address_1 <= Sp_address;

			IDCT_Mult1_op_1 <= $signed(R0_data_out_0[31:16]); //eg C(0,0) * S'(0,0)
			IDCT_Mult1_op_2 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_0[31:16]); //eg C(0,0) * S'(1,0)
			IDCT_Mult2_op_2 <= $signed(R0_data_out_1[15:0]);

			if (write_s_f == 1'd0) begin
				R1_address_1 <= S_address;
				S_address <= S_address + 7'd1;
				IDCT_SRAM_we_n <= 1'b0; // write mode

				IDCT_SRAM_address <= S_write_address + write_address_offset;
				S_counter <= S_counter + 6'd1;
				
				if ($signed(R1_data_out_1[31:16]) <= 0) //first value <0
					if ($signed(R1_data_out_1[15:0]) <= 0)
						IDCT_SRAM_write_data <= {8'd0, 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {8'd0, 8'd255};
					else
						IDCT_SRAM_write_data <= {8'd0, R1_data_out_1[7:0]};
						
				else if ($signed(R1_data_out_1[31:16]) >= 255) //first values >=255
					if ($signed(R1_data_out_1[15:0]) <= 0)
						IDCT_SRAM_write_data <= {8'd255, 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {8'd255, 8'd255};
					else
						IDCT_SRAM_write_data <= {8'd255, R1_data_out_1[7:0]};
						
				else //first value 0<x<255
					if ($signed(R1_data_out_1[15:0]) <= 0)
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd255};
					else
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], R1_data_out_1[7:0]};
			end

			IDCT_state <= S_IDCT_CALCT_LI3;
		end
		
		S_IDCT_CALCT_LI3: begin //LI2

			C_address <= C_address + 7'd4;
			Sp_address <= Sp_address + 7'd1;

			Calc_buf_0 <= IDCT_Mult1_result;
			Calc_buf_1 <= IDCT_Mult2_result;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_0[15:0]); //eg C(0,1) * S'(0,0)
			IDCT_Mult1_op_2 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_0[15:0]); //eg C(0,1) * S'(1,0)
			IDCT_Mult2_op_2 <= $signed(R0_data_out_1[15:0]);
			
			if (write_s_f == 1'd0) begin
				R1_address_1 <= S_address;
				S_address <= S_address + 7'd1;

				IDCT_SRAM_address <= S_write_address + write_address_offset;
				S_counter <= S_counter + 6'd1;
				
				if ($signed(R1_data_out_1[31:16]) <= 0) //first value <0
					if ($signed(R1_data_out_1[15:0]) <= 0)
						IDCT_SRAM_write_data <= {8'd0, 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {8'd0, 8'd255};
					else
						IDCT_SRAM_write_data <= {8'd0, R1_data_out_1[7:0]};
						
				else if ($signed(R1_data_out_1[31:16]) >= 255) //first values >=255
					if ($signed(R1_data_out_1[15:0]) < 0)
						IDCT_SRAM_write_data <= {8'd255, 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {8'd255, 8'd255};
					else
						IDCT_SRAM_write_data <= {8'd255, R1_data_out_1[7:0]};
						
				else //first value 0<x<255
					if ($signed(R1_data_out_1[15:0]) <= 0)
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd255};
					else
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], R1_data_out_1[7:0]};
			end

			IDCT_state <= S_IDCT_CALCT_LI4;
		end
		
		S_IDCT_CALCT_LI4: begin //LI3

			R0_address_0 <= C_address;
			R0_address_1 <= Sp_address;
			
			Calc_buf_2 <= IDCT_Mult1_result;
			Calc_buf_3 <= IDCT_Mult2_result;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_0[31:16]);
			IDCT_Mult1_op_2 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_0[31:16]); 
			IDCT_Mult2_op_2 <= $signed(R0_data_out_1[15:0]);
			
			if (write_s_f == 1'd0) begin
				R1_address_1 <= S_address;
				S_address <= S_address + 7'd1;

				IDCT_SRAM_address <= S_write_address + write_address_offset;
				S_counter <= S_counter + 6'd1;
				
				if ($signed(R1_data_out_1[31:16]) <= 0) //first value <0
					if ($signed(R1_data_out_1[15:0]) <= 0)
						IDCT_SRAM_write_data <= {8'd0, 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {8'd0, 8'd255};
					else
						IDCT_SRAM_write_data <= {8'd0, R1_data_out_1[7:0]};
						
				else if ($signed(R1_data_out_1[31:16]) >= 255) //first values >=255
					if ($signed(R1_data_out_1[15:0]) <= 0)
						IDCT_SRAM_write_data <= {8'd255, 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {8'd255, 8'd255};
					else
						IDCT_SRAM_write_data <= {8'd255, R1_data_out_1[7:0]};
						
				else //first value 0<x<255
					if ($signed(R1_data_out_1[15:0]) <= 0)
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd255};
					else
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], R1_data_out_1[7:0]};
			end

			IDCT_state <= S_IDCT_CALCT_0;
		end
		
		S_IDCT_CALCT_0: begin //Calc0

			Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
			Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_0[15:0]); 
			IDCT_Mult1_op_2 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_0[15:0]);
			IDCT_Mult2_op_2 <= $signed(R0_data_out_1[15:0]);
			
			if (Sp_address == 7'd31 && C_address == 7'd95) //all rows and columns done, T complete
				IDCT_state <= S_IDCT_CALCT_LO0;
			else if (C_address == 7'd95) begin //finished Sp row, move to next
				C_address <= 7'd64;
				Sp_address <= Sp_address + 7'd1;
				IDCT_state <= S_IDCT_CALCT_2;
			end
			else if (Sp_address[2:0] == 3'b111) begin //finshed C column, move to next
				C_address <= C_address - 7'd27;
				Sp_address <= Sp_address - 7'd7;
				IDCT_state <= S_IDCT_CALCT_2;
			end
			else begin
				C_address <= C_address + 7'd4; //finished multipltying two Sp values by two C values, continue cycle
				Sp_address <= Sp_address + 7'd1;
				IDCT_state <= S_IDCT_CALCT_1;
			end

			if (write_s_f == 1'd0) begin //request and recieve for S write
				if(S_address < 7'd96) begin
					R1_address_1 <= S_address;
					S_address <= S_address + 7'd1;
				end
				
				if (S_counter < 6'd32) begin //recieve for last two cycles of S write
					IDCT_SRAM_address <= S_write_address + write_address_offset;
					S_counter <= S_counter + 6'd1;
					
					if ($signed(R1_data_out_1[31:16]) <= 0) //first value <0
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd0, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd0, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd0, R1_data_out_1[7:0]};
							
					else if ($signed(R1_data_out_1[31:16]) >= 255) //first values >=255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd255, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd255, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd255, R1_data_out_1[7:0]};
							
					else //first value 0<x<255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd255};
						else
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], R1_data_out_1[7:0]};
				end
				else
					IDCT_SRAM_we_n <= 1'b1; // read mode since no more writing
			end
			
		end
		
		S_IDCT_CALCT_1: begin //Calc1

			R1_wren_0 <= 1'b0; //stop writing after write stages
			
			R0_address_0 <= C_address;
			R0_address_1 <= Sp_address;
			
			Calc_buf_2 <= IDCT_Mult1_result + Calc_buf_2;
			Calc_buf_3 <= IDCT_Mult2_result + Calc_buf_3;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_0[31:16]);
			IDCT_Mult1_op_2 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_0[31:16]); 
			IDCT_Mult2_op_2 <= $signed(R0_data_out_1[15:0]);
			
			IDCT_state <= S_IDCT_CALCT_0;

			if (write_s_f == 1'd0) begin //request and recieve for S write
				if(S_address < 7'd96) begin
					R1_address_1 <= S_address;
					S_address <= S_address + 7'd1;
				end
				
				if (S_counter < 6'd32) begin //recieve for last two cycles of S write
					IDCT_SRAM_address <= S_write_address + write_address_offset;
					S_counter <= S_counter + 6'd1;
					
					if ($signed(R1_data_out_1[31:16]) <= 0) //first value <0
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd0, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd0, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd0, R1_data_out_1[7:0]};
							
					else if ($signed(R1_data_out_1[31:16]) >= 255) //first values >=255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd255, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd255, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd255, R1_data_out_1[7:0]};
							
					else //first value 0<x<255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd255};
						else
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], R1_data_out_1[7:0]};
				end
				else
					IDCT_SRAM_we_n <= 1'b1; // read mode since no more writing
			end
		end
		
		S_IDCT_CALCT_2: begin
			R0_address_0 <= C_address;
			R0_address_1 <= Sp_address;

			R1_address_0 <= T_address;
			T_address <= T_address + 7'd8;

			R1_wren_0 <= 1'b1;
			R1_data_in_0 <= $signed(IDCT_Mult1_result + Calc_buf_0)>>>8;

			Calc_buf_2 <= IDCT_Mult1_result + Calc_buf_2;
			Calc_buf_3 <= IDCT_Mult2_result + Calc_buf_3;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_0[31:16]);
			IDCT_Mult1_op_2 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_0[31:16]); 
			IDCT_Mult2_op_2 <= $signed(R0_data_out_1[15:0]);
			
			IDCT_state <= S_IDCT_CALCT_3;

			if (write_s_f == 1'd0) begin //request and recieve for S write
				if(S_address < 7'd96) begin
					R1_address_1 <= S_address;
					S_address <= S_address + 7'd1;
				end
				
				if (S_counter < 6'd32) begin //recieve for last two cycles of S write
					IDCT_SRAM_address <= S_write_address + write_address_offset;
					S_counter <= S_counter + 6'd1;
					
					if ($signed(R1_data_out_1[31:16]) <= 0) //first value <0
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd0, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd0, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd0, R1_data_out_1[7:0]};
							
					else if ($signed(R1_data_out_1[31:16]) >= 255) //first values >=255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd255, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd255, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd255, R1_data_out_1[7:0]};
							
					else //first value 0<x<255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd255};
						else
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], R1_data_out_1[7:0]};
				end
				else
					IDCT_SRAM_we_n <= 1'b1; // read mode since no more writing
			end
		end
		
		S_IDCT_CALCT_3: begin
			C_address <= C_address + 7'd4;
			Sp_address <= Sp_address + 7'd1;

			R1_address_0 <= T_address;
			T_address <= T_address - 7'd7;

			R1_data_in_0 <= $signed(Calc_buf_1)>>>8;

			Calc_buf_0 <= IDCT_Mult1_result;
			Calc_buf_1 <= IDCT_Mult2_result;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_0[15:0]); 
			IDCT_Mult1_op_2 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_0[15:0]);
			IDCT_Mult2_op_2 <= $signed(R0_data_out_1[15:0]);
			
			IDCT_state <= S_IDCT_CALCT_4;

			if (write_s_f == 1'd0) begin //request and recieve for S write
				if(S_address < 7'd96) begin
					R1_address_1 <= S_address;
					S_address <= S_address + 7'd1;
				end
				
				if (S_counter < 6'd32) begin //recieve for last two cycles of S write
					IDCT_SRAM_address <= S_write_address + write_address_offset;
					S_counter <= S_counter + 6'd1;
					
					if ($signed(R1_data_out_1[31:16]) <= 0) //first value <0
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd0, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd0, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd0, R1_data_out_1[7:0]};
							
					else if ($signed(R1_data_out_1[31:16]) >= 255) //first values >=255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd255, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd255, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd255, R1_data_out_1[7:0]};
							
					else //first value 0<x<255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd255};
						else
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], R1_data_out_1[7:0]};
				end
				else
					IDCT_SRAM_we_n <= 1'b1; // read mode since no more writing
			end
		end
		
		S_IDCT_CALCT_4: begin
			R0_address_0 <= C_address;
			R0_address_1 <= Sp_address;

			R1_address_0 <= T_address;
			T_address <= T_address + 7'd8;

			R1_data_in_0 <= $signed(Calc_buf_2)>>>8;
			TS_buf_0 <= Calc_buf_3;

			Calc_buf_2 <= IDCT_Mult1_result;
			Calc_buf_3 <= IDCT_Mult2_result;

			IDCT_Mult1_op_1 <= $signed(R0_data_out_0[31:16]);
			IDCT_Mult1_op_2 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_0[31:16]); 
			IDCT_Mult2_op_2 <= $signed(R0_data_out_1[15:0]);

			IDCT_state <= S_IDCT_CALCT_5;

			if (write_s_f == 1'd0) begin //request and recieve for S write
				if(S_address < 7'd96) begin
					R1_address_1 <= S_address;
					S_address <= S_address + 7'd1;
				end
				
				if (S_counter < 6'd32) begin //recieve for last two cycles of S write
					IDCT_SRAM_address <= S_write_address + write_address_offset;
					S_counter <= S_counter + 6'd1;
					
					if ($signed(R1_data_out_1[31:16]) <= 0) //first value <0
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd0, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd0, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd0, R1_data_out_1[7:0]};
							
					else if ($signed(R1_data_out_1[31:16]) >= 255) //first values >=255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd255, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd255, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd255, R1_data_out_1[7:0]};
							
					else //first value 0<x<255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd255};
						else
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], R1_data_out_1[7:0]};
				end
				else
					IDCT_SRAM_we_n <= 1'b1; // read mode since no more writing
			end
		end

		S_IDCT_CALCT_5: begin
			
			C_address <= C_address + 7'd4;
			Sp_address <= Sp_address + 7'd1;
			R0_address_0 <= C_address;
			R0_address_1 <= Sp_address;
			R1_address_0 <= T_address;
			
			if (T_address[3:0] == 4'b1111)
				T_address <= T_address + 7'd1;
			else
				T_address <= T_address - 7'd7;
			
			R1_data_in_0 <= $signed(TS_buf_0)>>>8;

			Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
			Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_0[15:0]); 
			IDCT_Mult1_op_2 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_0[15:0]);
			IDCT_Mult2_op_2 <= $signed(R0_data_out_1[15:0]);

			IDCT_state <= S_IDCT_CALCT_1;
			if (write_s_f == 1'd0) begin //request and recieve for S write
				if(S_address < 7'd96) begin
					R1_address_1 <= S_address;
					S_address <= S_address + 7'd1;
				end
				
				if (S_counter < 6'd32) begin //recieve for last two cycles of S write
					IDCT_SRAM_address <= S_write_address + write_address_offset;
					S_counter <= S_counter + 6'd1;
					
					if ($signed(R1_data_out_1[31:16]) <= 0) //first value <0
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd0, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd0, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd0, R1_data_out_1[7:0]};
							
					else if ($signed(R1_data_out_1[31:16]) >= 255) //first values >=255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {8'd255, 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {8'd255, 8'd255};
						else
							IDCT_SRAM_write_data <= {8'd255, R1_data_out_1[7:0]};
							
					else //first value 0<x<255
						if ($signed(R1_data_out_1[15:0]) <= 0)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd0};
						else if ($signed(R1_data_out_1[15:0]) >= 255)
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd255};
						else
							IDCT_SRAM_write_data <= {R1_data_out_1[23:16], R1_data_out_1[7:0]};
				end
				else
					IDCT_SRAM_we_n <= 1'b1; // read mode since no more writing
			end
		end
		
		S_IDCT_CALCT_LO0: begin
			R1_address_0 <= T_address;
			T_address <= T_address + 7'd8;

			R1_wren_0 <= 1'b1;
			write_s_f <= 1'b0;
			R1_data_in_0 <= $signed(IDCT_Mult1_result + Calc_buf_0)>>>8;

			Calc_buf_2 <= IDCT_Mult1_result + Calc_buf_2;
			Calc_buf_3 <= IDCT_Mult2_result + Calc_buf_3;
			
			IDCT_state <= S_IDCT_CALCT_LO1;
			if (write_s_f == 1'b0) begin
				if (S_col_block_counter < max_column_blocks) begin
					S_col_block_counter <= S_col_block_counter + 6'd1;
					S_counter <= 6'd0;
				end
				else begin
					S_col_block_counter <= 6'd0;
					S_row_block_counter <= S_row_block_counter + 5'd1;
					S_counter <= 6'd0;
				end
			end
		end
		
		S_IDCT_CALCT_LO1: begin
			R1_address_0 <= T_address;
			T_address <= T_address - 7'd7;

			R1_data_in_0 <= $signed(Calc_buf_1)>>>8;
			
			IDCT_state <= S_IDCT_CALCT_LO2;
		end
		
		S_IDCT_CALCT_LO2: begin
			R1_address_0 <= T_address;
			T_address <= T_address + 7'd8;

			R1_data_in_0 <= Calc_buf_2;
			TS_buf_0 <= Calc_buf_3;
			
			IDCT_state <= S_IDCT_CALCT_LO3;

		end
		
		S_IDCT_CALCT_LO3: begin
			//could reset all calculate T addresses here
			R1_address_0 <= T_address;
			R1_data_in_0 <= TS_buf_0;
			if (Sp_row_block_counter == max_row_blocks && Sp_col_block_counter == max_column_blocks)
				IDCT_state <= S_IDCT_CALCSLO_LI0;//lead out state
			else
				IDCT_state <= S_IDCT_CALCS_LI0;
		end
		
		S_IDCT_CALCS_LI0: begin
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;
			R0_wren_0 <= 1'd0;
			R0_wren_1 <= 1'd0;
			R1_wren_0 <= 1'd0;
			Sp_address <= 7'd0;
			C_address <= 7'd64;
			T_address <= 7'd0;
			S_address <= 7'd64;
			fetch_sp_f <= 1'b1;
			S_state_counter <= 6'd0;
			S_lastreceive_counter <= 2'd0;
			S_mult_counter <= 3'd0;
			
			Sp_counter <= Sp_counter + 6'd8;
		
			IDCT_state <= S_IDCT_CALCS_LI1;
		end
		
		S_IDCT_CALCS_LI1: begin
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;			
			Sp_counter <= Sp_counter - 6'd7;
		
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			S_state_counter <= S_state_counter + 6'd1;
			
		
			IDCT_state <= S_IDCT_CALCS_LI2;
		end
		
		S_IDCT_CALCS_LI2: begin
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;			
			Sp_counter <= Sp_counter + 6'd8;
			
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			S_state_counter <= S_state_counter + 6'd1;
		
			IDCT_state <= S_IDCT_CALCS_LI3;
		end
		
		S_IDCT_CALCS_LI3: begin
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;
			Sp_data_buf <= SRAM_read_data;
			
			Sp_counter <= Sp_counter - 6'd7;
			
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			S_state_counter <= S_state_counter + 6'd1;
			
			Calc_buf_0 <= IDCT_Mult1_result;
			Calc_buf_1 <= IDCT_Mult2_result;
			
			S_mult_counter <= S_mult_counter + 3'd1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
		
			IDCT_state <= S_IDCT_CALCS_LI4;
		end
		
		S_IDCT_CALCS_LI4: begin
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;
			R0_wren_0 <= 1'd1;
			R0_address_0 <= 7'd0;
			R0_address_0 <= Sp_address;
			R0_data_in_0 <= {Sp_data_buf, SRAM_read_data};
			Sp_address <= Sp_address + 7'd1;
			
			Sp_counter <= Sp_counter + 6'd8;
			
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			S_state_counter <= S_state_counter + 6'd1;
			
			Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
			Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
			
			S_mult_counter <= S_mult_counter + 3'd1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
		
			IDCT_state <= S_IDCT_CALCS_LI5;
		end
		
		S_IDCT_CALCS_LI5: begin
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;
			R0_wren_0 <= 1'd0;
			Sp_data_buf <= SRAM_read_data;
			
			Sp_counter <= Sp_counter - 6'd7;
			
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			S_state_counter <= S_state_counter + 6'd1;
			
			Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
			Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
			
			S_mult_counter <= S_mult_counter + 3'd1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
		
			IDCT_state <= S_IDCT_CALCS_CC0;
		end
		
		S_IDCT_CALCS_CC0: begin
			R1_wren_1 <= 1'b0;
			if (fetch_sp_f == 1'b1) begin
				R0_wren_0 <= 1'd1;
			IDCT_SRAM_address <= Sp_read_address + read_address_offset;
				Sp_counter <= Sp_counter + 6'd8;
				R0_address_0 <= Sp_address; // Sp_address is used to keep track of where Sprime is being written in R0
				Sp_address <= Sp_address + 7'd1; // iterate Sp_address to make sure we write to the right position next time we write
				
				R0_data_in_0 <= {Sp_data_buf, SRAM_read_data};
			end
			else if ((fetch_sp_f == 1'b0) && (S_lastreceive_counter != 2'd3)) begin
				R0_wren_0 <= 1'd1;
				R0_address_0 <= Sp_address;
				Sp_address <= Sp_address + 7'd1;
				S_lastreceive_counter <= S_lastreceive_counter + 2'd1;
				R0_data_in_0 <= {Sp_data_buf, SRAM_read_data};
			end
			
			if (S_state_counter == 6'd63) begin // if to check whether we go into write to dram states
				S_state_counter <= 6'd0;
				C_address <= C_address - 7'd27;
				T_address <= 7'd0;
				R0_address_1 <= C_address;
				R1_address_0 <= T_address;
			end
			else if (S_state_counter[2:0] == 3'b111) begin
				S_state_counter <= S_state_counter + 6'd1;
				C_address <= C_address - 7'd28;
				T_address <= T_address - 7'd55;
				R0_address_1 <= C_address;
				R1_address_0 <= T_address;
			end
			else begin
				S_state_counter <= S_state_counter + 6'd1;
				C_address <= C_address + 7'd4;
				T_address <= T_address + 7'd8;
				R0_address_1 <= C_address;
				R1_address_0 <= T_address;
			end
			
			if (C_address == 7'd95 && T_address == 7'd63) begin // for the last calculation of S
				S_mult_counter <= 4'd0;
				Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
				Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
				IDCT_state <= S_IDCT_CALCS_LO0;
			end
			else if (S_mult_counter == 4'd15) begin
				S_mult_counter <= 4'd0;
				Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
				Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
				IDCT_state <= S_IDCT_CALCS_CC2;
			end
			else if (S_mult_counter == 4'd9) begin
				S_mult_counter <= S_mult_counter + 3'd1;
				Calc_buf_0 <= IDCT_Mult1_result;
				Calc_buf_1 <= IDCT_Mult2_result;
				IDCT_state <= S_IDCT_CALCS_CC1;
			end
			else begin
				S_mult_counter <= S_mult_counter + 3'd1;
				Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
				Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
				IDCT_state <= S_IDCT_CALCS_CC1;
			end
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
		end
		
		S_IDCT_CALCS_CC1: begin
			
			
			if (fetch_sp_f == 1'b1) begin
				R0_wren_0 <= 1'd0;
				if (Sp_counter == 6'd63) begin
					IDCT_SRAM_address <= Sp_read_address + read_address_offset;
					Sp_counter <= 6'd0;
					fetch_sp_f <= 1'b0;
					Sp_data_buf <= SRAM_read_data;
					if (Sp_col_block_counter == max_column_blocks) begin
						Sp_col_block_counter <= 6'd0;
						Sp_row_block_counter <= Sp_row_block_counter + 5'd1;
					end
					else
						Sp_col_block_counter <= Sp_col_block_counter + 6'd1;
				end
				else if (Sp_counter[3:0] == 4'd15) begin
					IDCT_SRAM_address <= Sp_read_address + read_address_offset;
					Sp_data_buf <= SRAM_read_data;
					Sp_counter <= Sp_counter + 6'd1;
				end
				else if (Sp_counter != 6'd0) begin
					IDCT_SRAM_address <= Sp_read_address + read_address_offset;
					Sp_data_buf <= SRAM_read_data;
					Sp_counter <= Sp_counter - 6'd7;
				end
			end
			else if ((fetch_sp_f == 1'b0) && (S_lastreceive_counter < 2'd3)) begin
				R0_wren_0 <= 1'd0;
				Sp_data_buf <= SRAM_read_data;
				S_lastreceive_counter <= S_lastreceive_counter + 2'd1;
			end
			
			if (S_mult_counter == 4'd8) begin
				Calc_buf_2 <= $signed(IDCT_Mult1_result + Calc_buf_0)>>>16;
				Calc_buf_3 <= $signed(IDCT_Mult2_result + Calc_buf_1)>>>16;
			end
			else begin
				Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
				Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
			end
			
			S_state_counter <= S_state_counter + 6'd1;
			
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			
			S_mult_counter <= S_mult_counter + 3'd1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
			
			IDCT_state <= S_IDCT_CALCS_CC0;
		end
		
		S_IDCT_CALCS_CC2: begin
			if (fetch_sp_f == 1'b1) begin
				R0_wren_0 <= 1'd0;
				if (Sp_counter == 6'd63) begin
					IDCT_SRAM_address <= Sp_read_address + read_address_offset;
					Sp_counter <= 6'd0;
					fetch_sp_f <= 1'b0;
					Sp_data_buf <= SRAM_read_data;
					if (Sp_col_block_counter == max_column_blocks) begin
						Sp_col_block_counter <= 6'd0;
						Sp_row_block_counter <= Sp_row_block_counter + 5'd1;
					end
					else
						Sp_col_block_counter <= Sp_col_block_counter + 6'd1;
				end
				else if (Sp_counter[3:0] == 4'd15) begin
					IDCT_SRAM_address <= Sp_read_address + read_address_offset;
					Sp_data_buf <= SRAM_read_data;
					Sp_counter <= Sp_counter + 6'd1;
				end
				else if (Sp_counter != 6'd0) begin
					IDCT_SRAM_address <= Sp_read_address + read_address_offset;
					Sp_data_buf <= SRAM_read_data;
					Sp_counter <= Sp_counter - 6'd7;
				end
			end
			else if ((fetch_sp_f == 1'b0) && (S_lastreceive_counter < 2'd3)) begin
				R0_wren_0 <= 1'd0;
				Sp_data_buf <= SRAM_read_data;
				S_lastreceive_counter <= S_lastreceive_counter + 2'd1;
			end
			
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			
			S_state_counter <= S_state_counter + 6'd1;
			
			TS_buf_0 <= $signed(IDCT_Mult1_result + Calc_buf_0)>>>16;
			TS_buf_1 <= $signed(IDCT_Mult2_result + Calc_buf_1)>>>16;
			
			S_mult_counter <= S_mult_counter + 3'd1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
			
			IDCT_state <= S_IDCT_CALCS_CC3;
		end
		
		S_IDCT_CALCS_CC3: begin
		
			if (fetch_sp_f == 1'b1) begin
				R0_wren_0 <= 1'd1;
				IDCT_SRAM_address <= Sp_read_address + read_address_offset;
				Sp_counter <= Sp_counter + 6'd8;
				R0_address_0 <= Sp_address; // Sp_address is used to keep track of where Sprime is being written in R0
				Sp_address <= Sp_address + 7'd1; // iterate Sp_address to make sure we write to the right position next time we write
				
				R0_data_in_0 <= {Sp_data_buf, SRAM_read_data};
			end
			else if ((fetch_sp_f == 1'b0) && (S_lastreceive_counter != 2'd3)) begin
				R0_wren_0 <= 1'd1;
				R0_address_0 <= Sp_address;
				Sp_address <= Sp_address + 7'd1;
				S_lastreceive_counter <= S_lastreceive_counter + 2'd1;
				R0_data_in_0 <= {Sp_data_buf, SRAM_read_data};
			end
			
			R1_wren_1 <= 1'd1;
			R1_address_1 <= S_address;
			R1_data_in_1 <= {Calc_buf_2[15:0], TS_buf_0[15:0]};
			
			S_address <= S_address + 7'd4;
			S_state_counter <= S_state_counter + 6'd1;
			S_mult_counter <= S_mult_counter + 3'd1;
			
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			
			Calc_buf_0 <= IDCT_Mult1_result;
			Calc_buf_1 <= IDCT_Mult2_result;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
			
			IDCT_state <= S_IDCT_CALCS_CC4;
		end
		
		S_IDCT_CALCS_CC4: begin
		
			if (fetch_sp_f == 1'b1) begin
				R0_wren_0 <= 1'd0;
				if (Sp_counter == 6'd63) begin
					IDCT_SRAM_address <= Sp_read_address + read_address_offset;
					Sp_counter <= 6'd0;
					fetch_sp_f <= 1'b0;
					Sp_data_buf <= SRAM_read_data;
					if (Sp_col_block_counter == max_column_blocks) begin
						Sp_col_block_counter <= 6'd0;
						Sp_row_block_counter <= Sp_row_block_counter + 5'd1;
					end
					else
						Sp_col_block_counter <= Sp_col_block_counter + 6'd1;
				end
				else if (Sp_counter[3:0] == 4'd15) begin
					IDCT_SRAM_address <= Sp_read_address + read_address_offset;
					Sp_data_buf <= SRAM_read_data;
					Sp_counter <= Sp_counter + 6'd1;
				end
				else if (Sp_counter != 6'd0) begin
					IDCT_SRAM_address <= Sp_read_address + read_address_offset;
					Sp_data_buf <= SRAM_read_data;
					Sp_counter <= Sp_counter - 6'd7;
				end
			end
			else if ((fetch_sp_f == 1'b0) && (S_lastreceive_counter < 2'd3)) begin
				R0_wren_0 <= 1'd0;
				Sp_data_buf <= SRAM_read_data;
				S_lastreceive_counter <= S_lastreceive_counter + 2'd1;
			end
			
			R1_wren_1 <= 1'd1;
			if (S_address[2:0] == 3'b111)
				S_address <= S_address + 7'd1;
			else
				S_address <= S_address - 7'd3;
			
			R1_address_1 <= S_address;
			R1_data_in_1 <= {Calc_buf_3[15:0], TS_buf_1[15:0]};
			
			S_state_counter <= S_state_counter + 6'd1;
			S_mult_counter <= S_mult_counter + 3'd1;
			
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			
			Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
			Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
			
			IDCT_state <= S_IDCT_CALCS_CC0;
		end
		
		S_IDCT_CALCS_LO0: begin
			TS_buf_0 <= $signed(IDCT_Mult1_result + Calc_buf_0)>>>16;
			TS_buf_1 <= $signed(IDCT_Mult2_result + Calc_buf_1)>>>16;
			
			IDCT_state <= S_IDCT_CALCS_LO1;
		end
		
		S_IDCT_CALCS_LO1: begin
			
			R1_wren_1 <= 1'd1;
			R1_address_1 <= S_address;
			R1_data_in_1 <= {Calc_buf_2[15:0], TS_buf_0[15:0]};
			
			S_address <= S_address + 7'd4;
			
			IDCT_state <= S_IDCT_CALCS_LO2;
		end
		
		S_IDCT_CALCS_LO2: begin
			R1_address_1 <= S_address;
			R1_data_in_1 <= {Calc_buf_3[15:0], TS_buf_1[15:0]};
			
			Sp_address <= 7'd0;
			S_address <= 7'd64;
			S_state_counter <= 6'd0;
			S_mult_counter <= 3'd0;
			C_address <= 7'd64;
			T_address <= 7'd0;
			Sp_counter <= 6'd0;
			IDCT_state <= S_IDCT_CALCT_LI0;
		end
		
		
		S_IDCT_CALCSLO_LI0: begin
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			S_state_counter <= S_state_counter + 6'd1;
			
			
			IDCT_state <= S_IDCT_CALCSLO_LI1;
		end
		
		S_IDCT_CALCSLO_LI1: begin
			
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			S_state_counter <= S_state_counter + 6'd1;
		
			IDCT_state <= S_IDCT_CALCSLO_LI2;
		end
		
		S_IDCT_CALCSLO_LI2: begin
			
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			S_state_counter <= S_state_counter + 6'd1;
			
			Calc_buf_0 <= IDCT_Mult1_result;
			Calc_buf_1 <= IDCT_Mult2_result;
			
			S_mult_counter <= S_mult_counter + 3'd1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
			
			IDCT_state <= S_IDCT_CALCSLO_CC0;
		end
		
		S_IDCT_CALCSLO_CC0: begin
		
			if (S_state_counter == 6'd63) begin // if to check whether we go into write to dram states
				S_state_counter <= 6'd0;
				C_address <= C_address - 7'd27;
				T_address <= 7'd0;
				R0_address_1 <= C_address;
				R1_address_0 <= T_address;
			end
			else if (S_state_counter[2:0] == 3'b111) begin
				S_state_counter <= S_state_counter + 6'd1;
				C_address <= C_address - 7'd28;
				T_address <= T_address - 7'd55;
				R0_address_1 <= C_address;
				R1_address_0 <= T_address;
			end
			else begin
				S_state_counter <= S_state_counter + 6'd1;
				C_address <= C_address + 7'd4;
				T_address <= T_address + 7'd8;
				R0_address_1 <= C_address;
				R1_address_0 <= T_address;
			end
			
			if (C_address == 7'd95 && T_address == 7'd63) begin // for the last calculation of S
				S_mult_counter <= 4'd0;
				Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
				Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
				IDCT_state <= S_IDCT_CALCS_LO0;
			end
			else if (S_mult_counter == 4'd15) begin
				S_mult_counter <= 4'd0;
				Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
				Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
				IDCT_state <= S_IDCT_CALCS_CC2;
			end
			else if (S_mult_counter == 4'd9) begin
				S_mult_counter <= S_mult_counter + 3'd1;
				Calc_buf_0 <= IDCT_Mult1_result;
				Calc_buf_1 <= IDCT_Mult2_result;
				IDCT_state <= S_IDCT_CALCS_CC1;
			end
			else begin
				S_mult_counter <= S_mult_counter + 3'd1;
				Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
				Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
				IDCT_state <= S_IDCT_CALCS_CC1;
			end
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
			
			IDCT_state <= S_IDCT_CALCSLO_CC1;
		end
		
		S_IDCT_CALCSLO_CC1: begin
		
			if (S_mult_counter == 4'd8) begin
				Calc_buf_2 <= $signed(IDCT_Mult1_result + Calc_buf_0)>>>16;
				Calc_buf_3 <= $signed(IDCT_Mult2_result + Calc_buf_1)>>>16;
			end
			else begin
				Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
				Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
			end
			
			S_state_counter <= S_state_counter + 6'd1;
			
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			
			S_mult_counter <= S_mult_counter + 3'd1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
			
			IDCT_state <= S_IDCT_CALCSLO_CC2;
		end
		
		S_IDCT_CALCSLO_CC2: begin
		
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			
			S_state_counter <= S_state_counter + 6'd1;
			
			TS_buf_0 <= $signed(IDCT_Mult1_result + Calc_buf_0)>>>16;
			TS_buf_1 <= $signed(IDCT_Mult2_result + Calc_buf_1)>>>16;
			
			S_mult_counter <= S_mult_counter + 3'd1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
			
			IDCT_state <= S_IDCT_CALCSLO_CC3;
		end
		
		S_IDCT_CALCSLO_CC3: begin
			
			R1_wren_1 <= 1'd1;
			R1_address_1 <= S_address;
			R1_data_in_1 <= {Calc_buf_2[15:0], TS_buf_0[15:0]};
			
			S_address <= S_address + 7'd4;
			S_state_counter <= S_state_counter + 6'd1;
			S_mult_counter <= S_mult_counter + 3'd1;
			
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			
			Calc_buf_0 <= IDCT_Mult1_result;
			Calc_buf_1 <= IDCT_Mult2_result;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
			
			IDCT_state <= S_IDCT_CALCSLO_CC4;
		end
		
		S_IDCT_CALCSLO_CC4: begin
			
			R1_wren_1 <= 1'd1;
			if (S_address[2:0] == 3'b111)
				S_address <= S_address + 7'd1;
			else
				S_address <= S_address - 7'd3;
			
			R1_address_1 <= S_address;
			R1_data_in_1 <= {Calc_buf_3[15:0], TS_buf_1[15:0]};
			
			S_state_counter <= S_state_counter + 6'd1;
			S_mult_counter <= S_mult_counter + 3'd1;
			
			C_address <= C_address + 7'd4;
			T_address <= T_address + 7'd8;
			R0_address_1 <= C_address;
			R1_address_0 <= T_address;
			
			Calc_buf_0 <= IDCT_Mult1_result + Calc_buf_0;
			Calc_buf_1 <= IDCT_Mult2_result + Calc_buf_1;
			
			IDCT_Mult1_op_1 <= $signed(R0_data_out_1[31:16]);
			IDCT_Mult1_op_2 <= $signed(R1_data_out_0);
			IDCT_Mult2_op_1 <= $signed(R0_data_out_1[15:0]);
			IDCT_Mult2_op_2 <= $signed(R1_data_out_0);
			
			IDCT_state <= S_IDCT_CALCSLO_LO0;
		end
		
		S_IDCT_CALCSLO_LO0: begin
			TS_buf_0 <= $signed(IDCT_Mult1_result + Calc_buf_0)>>>16;
			TS_buf_1 <= $signed(IDCT_Mult2_result + Calc_buf_1)>>>16;
			
			IDCT_state <= S_IDCT_CALCSLO_LO1;
		end
		
		S_IDCT_CALCSLO_LO1: begin
			R1_wren_1 <= 1'd1;
			R1_address_1 <= S_address;
			R1_data_in_1 <= {Calc_buf_2[15:0], TS_buf_0[15:0]};
			
			S_address <= S_address + 7'd4;
			
			IDCT_state <= S_IDCT_CALCSLO_LO2;
		end
		
		S_IDCT_CALCSLO_LO2: begin
		
			R1_address_1 <= S_address;
			R1_data_in_1 <= {Calc_buf_3[15:0], TS_buf_1[15:0]};
			
			Sp_address <= 7'd0;
			S_address <= 7'd64;
			S_state_counter <= 6'd0;
			S_mult_counter <= 3'd0;
			C_address <= 7'd64;
			T_address <= 7'd0;
			Sp_counter <= 6'd0;
			
			IDCT_state <= S_IDCT_WRITES_LI0;
		end
		
		S_IDCT_WRITES_LI0: begin
		
			R1_address_1 <= S_address;
			S_address <= S_address + 7'd1;
			
			IDCT_state <= S_IDCT_WRITES_LI1;
		end
		
		S_IDCT_WRITES_LI1: begin
			
			R1_address_1 <= S_address;
			S_address <= S_address + 7'd1;
			
			IDCT_state <= S_IDCT_WRITES_0;
		end
		
		S_IDCT_WRITES_0: begin
			
			R1_address_1 <= S_address;
			S_address <= S_address + 7'd1;
			IDCT_SRAM_we_n <= 1'b0; // write mode

			IDCT_SRAM_address <= S_write_address + write_address_offset;
			S_counter <= S_counter + 6'd1;
			
			if(S_address < 7'd96) begin
				R1_address_1 <= S_address;
				S_address <= S_address + 7'd1;
			end
				
			if (S_counter < 6'd32) begin //recieve for last two cycles of S write
				IDCT_SRAM_address <= S_write_address + write_address_offset;
				S_counter <= S_counter + 6'd1;
				IDCT_state <= S_IDCT_WRITES_1;
				
				if ($signed(R1_data_out_1[31:16]) < 0) //first value <0
					if ($signed(R1_data_out_1[15:0]) < 0)
						IDCT_SRAM_write_data <= {8'd0, 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {8'd0, 8'd255};
					else
						IDCT_SRAM_write_data <= {8'd0, R1_data_out_1[7:0]};
						
				else if ($signed(R1_data_out_1[31:16]) >= 255) //first values >=255
					if ($signed(R1_data_out_1[15:0]) < 0)
						IDCT_SRAM_write_data <= {8'd255, 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {8'd255, 8'd255};
					else
						IDCT_SRAM_write_data <= {8'd255, R1_data_out_1[7:0]};
						
				else //first value 0<x<255
					if ($signed(R1_data_out_1[15:0]) < 0)
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd255};
					else
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], R1_data_out_1[7:0]};
			end
			else
				IDCT_SRAM_we_n <= 1'b1; // read mode since no more writing
				IDCT_state <= S_IDCT_WRITES_LO;
			
			
		end
		
		S_IDCT_WRITES_1: begin
			R1_address_1 <= S_address;
			S_address <= S_address + 7'd1;

			IDCT_SRAM_address <= S_write_address + write_address_offset;
			S_counter <= S_counter + 6'd1;
			
			if(S_address < 7'd96) begin
				R1_address_1 <= S_address;
				S_address <= S_address + 7'd1;
			end
				
			if (S_counter < 6'd32) begin //recieve for last two cycles of S write
				IDCT_SRAM_address <= S_write_address + write_address_offset;
				S_counter <= S_counter + 6'd1;
				IDCT_state <= S_IDCT_WRITES_0;
				
				if ($signed(R1_data_out_1[31:16]) < 0) //first value <0
					if ($signed(R1_data_out_1[15:0]) < 0)
						IDCT_SRAM_write_data <= {8'd0, 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {8'd0, 8'd255};
					else
						IDCT_SRAM_write_data <= {8'd0, R1_data_out_1[7:0]};
						
				else if ($signed(R1_data_out_1[31:16]) >= 255) //first values >=255
					if ($signed(R1_data_out_1[15:0]) < 0)
						IDCT_SRAM_write_data <= {8'd255, 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {8'd255, 8'd255};
					else
						IDCT_SRAM_write_data <= {8'd255, R1_data_out_1[7:0]};
						
				else //first value 0<x<255
					if ($signed(R1_data_out_1[15:0]) < 0)
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd0};
					else if ($signed(R1_data_out_1[15:0]) >= 255)
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], 8'd255};
					else
						IDCT_SRAM_write_data <= {R1_data_out_1[23:16], R1_data_out_1[7:0]};
			end
			else
				IDCT_SRAM_we_n <= 1'b1; // read mode since no more writing
				IDCT_state <= S_IDCT_WRITES_LO;
		end
		
		S_IDCT_WRITES_LO: begin
			S_row_block_counter <= 5'd0;
			S_col_block_counter <= 6'd0;
			Sp_col_block_counter <= 6'd0;
			Sp_row_block_counter <= 5'd0;
			Sp_counter <= 6'd0;
			S_counter <= 6'd0;
			UV_transition <= UV_transition + 2'd1;
			
			IDCT_state <= S_IDCT_IDLE;
		end
		
		default: IDCT_state <= S_IDCT_IDLE;
		
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
	else if (top_state == S_IDCT_TOP) begin
		SRAM_address = IDCT_SRAM_address;
		SRAM_write_data = IDCT_SRAM_write_data;
		SRAM_we_n = IDCT_SRAM_we_n;
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




always_comb begin
	if (UV_transition == 2'b0)begin
		read_address_offset = 18'd76800;
		write_address_offset = 18'd0;
		max_column_blocks = 6'd39;
		max_row_blocks = 5'd29;
		
		Sp_RA = {Sp_row_block_counter, Sp_counter[5:3]}; //8bit
		Sp_CA = {Sp_col_block_counter, Sp_counter[2:0]}; //9bit
		Sp_read_address = {Sp_RA, 8'd0} + {Sp_RA, 6'd0} + Sp_CA;
		
		S_RA = {S_row_block_counter, S_counter[4:2]}; //8bit
		S_CA = {S_col_block_counter, S_counter[1:0]}; //9bit
		S_write_address = {S_RA, 7'd0} + {S_RA, 5'd0} + S_CA;
	end
		
	else if (UV_transition == 2'b1)begin
		read_address_offset = 18'd153600;
		write_address_offset = 18'd38400;
		max_column_blocks = 6'd19;
		max_row_blocks = 5'd29;
		
		Sp_RA = {Sp_row_block_counter, Sp_counter[5:3]}; //8bit
		Sp_CA = {Sp_col_block_counter, Sp_counter[2:0]}; //9bit
		Sp_read_address = {Sp_RA, 7'd0} + {Sp_RA, 5'd0} + Sp_CA;
		
		S_RA = {S_row_block_counter, S_counter[4:2]}; //8bit
		S_CA = {S_col_block_counter, S_counter[1:0]}; //9bit
		S_write_address = {S_RA, 6'd0} + {S_RA, 4'd0} + S_CA;
	end
	
	else begin
		read_address_offset = 18'd192000;
		write_address_offset = 18'd57600;
		max_column_blocks = 6'd19;
		max_row_blocks = 5'd29;
		
		Sp_RA = {Sp_row_block_counter, Sp_counter[5:3]}; //8bit
		Sp_CA = {Sp_col_block_counter, Sp_counter[2:0]}; //9bit
		Sp_read_address = {Sp_RA, 7'd0} + {Sp_RA, 5'd0} + Sp_CA;
		
		S_RA = {S_row_block_counter, S_counter[4:2]}; //8bit
		S_CA = {S_col_block_counter, S_counter[1:0]}; //9bit
		S_write_address = {S_RA, 6'd0} + {S_RA, 4'd0} + S_CA;
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
