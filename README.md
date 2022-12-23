## Digital Systems Design Project

This project was done in collaboration with Arjun Snider and was completed on November 29th, 2022

### Objective

In this project, students will gain experience in digital system design by implementing the custom McMaster Image Compression revision 16 (.mic16) image compression specification in hardware. Compressed data for a 320 x 240 pixel image will be delivered to the Altera DE2 board via the universal asynchronous receiver/transmitter (UART) interface from a personal computer (PC) and stored in the external static random access memory (SRAM). The image decoding circuitry will read the compressed data, recover the image using a custom digital circuit designed by you and store it back to the SRAM, from where the video graphics array (VGA) controller will read it and display it to the monitor.