`ifndef DEFINE_STATE

// for top state - we have more states than needed
typedef enum logic [2:0] {
	S_IDLE,
	S_UART_RX,
	S_UPS_CSC_TOP,
	S_VGA_Output
} top_state_type;

typedef enum logic [4:0] {
	S_CC_IDLE,
	S_Start_0,
	S_Start_1,
	S_Start_2,
	S_Start_3,
	S_Start_4,
	S_Start_5,
	S_Start_6,
	S_Start_7,
	S_CC_0,
	S_CC_1,
	S_CC_2,
	S_CC_3,
	S_CC_4,
	S_CC_5,
	S_CC_6,
	S_CC_7,
	S_LO_0,
	S_LO_1,
	S_LO_2,
	S_LO_3,
	S_LO_4,
	S_LO_5,
	S_LO_6,
	S_LO_7,
	S_LOF_0,
	S_LOF_1,
	S_LOF_2
} UPS_CSC_state_type;


typedef enum logic [1:0] {
	S_RXC_IDLE,
	S_RXC_SYNC,
	S_RXC_ASSEMBLE_DATA,
	S_RXC_STOP_BIT
} RX_Controller_state_type;

typedef enum logic [2:0] {
	S_US_IDLE,
	S_US_STRIP_FILE_HEADER_1,
	S_US_STRIP_FILE_HEADER_2,
	S_US_START_FIRST_BYTE_RECEIVE,
	S_US_WRITE_FIRST_BYTE,
	S_US_START_SECOND_BYTE_RECEIVE,
	S_US_WRITE_SECOND_BYTE
} UART_SRAM_state_type;

typedef enum logic [3:0] {
	S_VS_WAIT_NEW_PIXEL_ROW,
	S_VS_NEW_PIXEL_ROW_DELAY_1,
	S_VS_NEW_PIXEL_ROW_DELAY_2,
	S_VS_NEW_PIXEL_ROW_DELAY_3,
	S_VS_NEW_PIXEL_ROW_DELAY_4,
	S_VS_NEW_PIXEL_ROW_DELAY_5,
	S_VS_FETCH_PIXEL_DATA_0,
	S_VS_FETCH_PIXEL_DATA_1,
	S_VS_FETCH_PIXEL_DATA_2,
	S_VS_FETCH_PIXEL_DATA_3
} VGA_SRAM_state_type;

parameter 
   VIEW_AREA_LEFT = 160,
   VIEW_AREA_RIGHT = 480,
   VIEW_AREA_TOP = 120,
   VIEW_AREA_BOTTOM = 360;

`define DEFINE_STATE 1
`endif
