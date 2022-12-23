# activate waveform simulation

view wave

# format signal names in waveform

configure wave -signalnamewidth 1
configure wave -timeline 0
configure wave -timelineunits us

# add signals to waveform

add wave -divider -height 20 {Top-level signals}
add wave -bin UUT/CLOCK_50_I
add wave -bin UUT/resetn
add wave UUT/top_state
add wave UUT/CC_state
add wave -uns UUT/UART_timer

add wave -divider -height 10 {SRAM signals}
add wave -uns UUT/SRAM_address
add wave -hex UUT/SRAM_write_data
add wave -hex UUT/SRAM_read_data
add wave -bin UUT/SRAM_we_n
add wave -bin UUT/Start_f
add wave -bin UUT/Req_f
add wave -hex UUT/R
add wave -hex UUT/G
add wave -hex UUT/B
add wave -hex UUT/Rbuf
add wave -hex UUT/Gbuf
add wave -hex UUT/Bbuf
add wave -uns UUT/write_count
add wave -uns UUT/U_request_count
add wave -uns UUT/Row_counter

add wave -divider -height 10 {YUV Values}
add wave -hex UUT/U
add wave -hex UUT/V
add wave -hex UUT/Y
add wave -hex UUT/Uin
add wave -hex UUT/Vin
add wave -hex UUT/U_prime_even
add wave -hex UUT/V_prime_even
add wave -hex UUT/U_prime_odd
add wave -hex UUT/V_prime_odd
add wave -hex UUT/Yval
add wave -hex UUT/Mult1_result
add wave -hex UUT/Mult2_result
add wave -hex UUT/Mult3_result


add wave -divider -height 10 {VGA signals}
add wave -bin UUT/VGA_unit/VGA_HSYNC_O
add wave -bin UUT/VGA_unit/VGA_VSYNC_O
add wave -uns UUT/VGA_unit/pixel_X_pos
add wave -uns UUT/VGA_unit/pixel_Y_pos
add wave -hex UUT/VGA_unit/VGA_red
add wave -hex UUT/VGA_unit/VGA_green
add wave -hex UUT/VGA_unit/VGA_blue

