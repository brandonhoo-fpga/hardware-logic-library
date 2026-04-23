// ============================================================================
// File Name   : Morse_Top.v
// Author      : Brandon Hoo
// Description : Top-Level code for the Morse Code Decoder. Integrates the 
//               debouncers, the main Morse FSM, and the UART transmitter.
// ============================================================================

module Morse_Top(
    input i_Clk,        // 25MHz System Clock
    input i_Switch_1,   // Switch for Main Morse Key
    input i_Switch_2,   // Switch to Submit Sentence
    input i_Switch_3,   // Switch to Delete Dot/Dash
    output o_LED_1,     // Dot registered indicator
    output o_LED_2,     // Dash registered indicator
    output o_LED_3,     // Letter submitted indicator
    output o_LED_4,     // Word space submitted indicator
    output o_UART_TX    // Serial data out to PC
);

// UART Communication Signals
wire w_UART_DV;
wire [7:0] w_UART_Byte;
wire w_UART_Active;
wire w_UART_Serial;
wire w_UART_Done;

// FSM to LED Status Wires
wire w_DOT_LED;
wire w_DASH_LED;
wire w_LETTER_LED;
wire w_WORD_LED;

// Debounced Switch Signals
wire w_Switch_1;
wire w_Switch_2;
wire w_Switch_3;

// Instantiation of Debounce Module for Switch 1
Debounce Debounce_Inst1(
    .i_Clk(i_Clk),
    .i_Switch(i_Switch_1),
    .o_Switch(w_Switch_1)
);

// Instantiation of Debounce Module for Switch 2
Debounce Debounce_Inst2(
    .i_Clk(i_Clk),
    .i_Switch(i_Switch_2),
    .o_Switch(w_Switch_2)
);

// Instantiation of Debounce Module for Switch 3
Debounce Debounce_Inst3(
    .i_Clk(i_Clk),
    .i_Switch(i_Switch_3),
    .o_Switch(w_Switch_3)
);

// UART Transmitter (Baud: 115200 | 25MHz / 115200 = 217 clks/bit)
UART_TX #(.CLKS_PER_BIT(217)) UART_TX_Inst(
    .i_Rst_L(1'b1),
    .i_Clock(i_Clk),
    .i_TX_DV(w_UART_DV),
    .i_TX_Byte(w_UART_Byte),
    .o_TX_Active(w_UART_Active),
    .o_TX_Serial(w_UART_Serial),
    .o_TX_Done(w_UART_Done)
);

// Instantiation of Morse Code FSM
// Translates button presses into UART transmission bytes
Morse_FSM Morse_Inst(
    .i_Clock(i_Clk),
    .i_Switch_1(w_Switch_1),
    .i_Switch_2(w_Switch_2),
    .i_Switch_3(w_Switch_3),
    .i_UART_Active(w_UART_Active),
    .i_UART_Done(w_UART_Done),
    .o_UART_Byte(w_UART_Byte),
    .o_UART_DV(w_UART_DV),
    .o_DOT_LED(w_DOT_LED),
    .o_DASH_LED(w_DASH_LED),
    .o_LETTER_LED(w_LETTER_LED),
    .o_WORD_LED(w_WORD_LED)
);

// Drive the physical board outputs with internal logic wires
assign o_LED_1 = w_DOT_LED;
assign o_LED_2 = w_DASH_LED;
assign o_LED_3 = w_LETTER_LED;
assign o_LED_4 = w_WORD_LED;
assign o_UART_TX = w_UART_Serial;


endmodule