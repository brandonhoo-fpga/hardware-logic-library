# Hardware Logic Library

A personal collection of reusable Verilog modules I've built up across my FPGA projects. Most started as utilities for specific projects (Morse code decoder, Pong, Mandelbrot) and got pulled out here for reuse.

The modules are parameterized and target-agnostic where possible, so the same code drops into a Lattice iCE40 (Nandland Go Board) or Cyclone IV (Terasic DE2-115) design without modification.

## Modules
- **Display:** Binary_to_7Seg, VGA_Sync_Pulses, VGA_Sync_Porch
- **Input:** Debounce
- **Communication:** UART_TX, UART_RX *(adapted from Russell Merrick's [Nandland](https://nandland.com) tutorials)*
