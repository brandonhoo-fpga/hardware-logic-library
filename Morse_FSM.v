// ============================================================================
// File Name   : Morse_FSM.v   
// Author      : Brandon Hoo
// Description : State machine that decodes raw timing pulses into valid Morse
//               characters and buffers them for UART transmission. Features a
//               dual-layer memory architecture for live-echo and batch submit
// ============================================================================

module Morse_FSM (
    input           i_Clock,                // 25MHz System Clock
    input           i_Switch_1,             // Morse Pulse (Dot/Dash/Letter/Word evaluated by duration)
    input           i_Switch_2,             // Submit buffered sentence
    input           i_Switch_3,             // Backspace last buffer entry
    input           i_UART_Active,          // Set High when UART is currently transmitting 
    input           i_UART_Done,            // Pulses Highwhen UART finishes byte 
    output reg[7:0] o_UART_Byte,            // Data loaded into UART transmitter
    output reg      o_UART_DV,              // Data Valid pulse to trigger UART transmission
    output reg      o_DOT_LED = 1'b0,       // Set High when Dot timing threshold is passed
    output reg      o_DASH_LED = 1'b0,      // Set High when Dash timing threshold is passed
    output reg      o_LETTER_LED = 1'b0,    // Set High when Letter timing threshold is passed
    output reg      o_WORD_LED = 1'b0       // Set High when Word timing threshold is passed
);

// Timing Threshold Parameters (25MHz -> 40ns clock cycle)
localparam c_THRESHOLD_DASH = 12500000; // 12,500,000 cycles = 0.5s
localparam c_THRESHOLD_LETTER = 25000000; // 25,000,000 cycles = 1s
localparam c_THRESHOLD_WORD = 50000000; // 50,000,000 cycles = 2s

// State Machine Declaration
localparam IDLE = 3'b000;
localparam MEASURE = 3'b001;
localparam EVALUATE = 3'b010;
localparam APPEND_LF = 3'b011;
localparam TRANSMIT = 3'b100;
localparam ECHO_CHAR = 3'b101;
localparam ECHO_WAIT = 3'b110;

// Sub-state Machine for UART Transmission
localparam TX_CHECK_INDEX = 2'b00;
localparam TX_SEND_BYTE = 2'b01;
localparam TX_WAIT_DONE = 2'b10;

// State Machine Registers
reg[2:0] r_SM_Main = 0;
reg[1:0] r_TX_State = 0;


reg[4:0] letter_buffer = 5'b00001; // 5-bit Morse buffer with a framing bit (Leading 1)
reg[$clog2(c_THRESHOLD_WORD)-1:0] r_COUNT = 0; // Sized register to safely hold maximum word count

// Synchronized inputs t detect edge transitions
reg r_Switch_1 = 1'b0;
reg r_Switch_2 = 1'b0;
reg r_Switch_3 = 1'b0;

// 32-Byte RAM block for batch sentence submission
// can only hold 32 characters which includes spaces and next lines
// write and read index are used for transmitting characters to UART
reg[7:0] sentence_memory [0:31];
reg[5:0] write_index = 6'd2;
reg[5:0] read_index = 6'd0;

// Wire to recieve decoded ASCII character from Letter_Convert
wire[7:0] w_decoded_ascii; 

// Combinational LUT to map current 5-bit buffer to ASCII hex value
Letter_Convert Letter_Inst (
    .letter_buffer(letter_buffer),
    .ascii_hex(w_decoded_ascii)
);

// Pre-loaded to start of the memory block with
// 8'h0D = Carriage Return
// 8'h0A = Line Feed
initial
begin
    sentence_memory[0] = 8'h0D;
    sentence_memory[1] = 8'h0A;
end


always @(posedge i_Clock)
begin
    // Register the physical inputs for edge detection
    r_Switch_1 <= i_Switch_1;
    r_Switch_2 <= i_Switch_2;
    r_Switch_3 <= i_Switch_3;

    // Default pulse low - Data not ready to transmit
    o_UART_DV <= 1'b0;

    case (r_SM_Main)
        
        IDLE :
        begin
            // Clear counters and status indicators
            r_COUNT <= 0;
            o_DOT_LED <= 1'b0;
            o_DASH_LED <= 1'b0;
            o_LETTER_LED <= 1'b0;
            o_WORD_LED <= 1'b0;

            // Change state at rising edge to measure Morse Pulse signal
            if (r_Switch_1 == 1'b0 && i_Switch_1 == 1'b1)
                r_SM_Main <= MEASURE;
            // Change state to start transmiting sentence
            else if (r_Switch_2 == 1'b1 && i_Switch_2 == 1'b0)
            begin    
                sentence_memory[write_index] <= 8'h0D; // Append Carriage Return
                write_index <= write_index + 1;
                r_SM_Main <= APPEND_LF; 
            end
            // Backspace logic: Shift buffer right, echo backspace character
            else if (r_Switch_3 == 1'b1 && i_Switch_3 == 1'b0)
            begin
                letter_buffer <= {1'b0, letter_buffer[4:1]};
                o_UART_Byte <= 8'h08;
                r_SM_Main <= ECHO_CHAR;
            end
            else
                r_SM_Main <= IDLE;
        end

        MEASURE :
        begin
            // Memory protection: Abort to IDLE if RAM buffer is full
            if (write_index >= 6'd29)
                r_SM_Main <= IDLE;
            // Switch released: Move to start evaluation
            else if(r_Switch_1 == 1'b1 && i_Switch_1 == 1'b0)
                    r_SM_Main <= EVALUATE;
            // Switch held: Accumulate clock cycles and update LEDs
            else
            begin
                    r_COUNT <= r_COUNT + 1;
                    r_SM_Main <= MEASURE;
            
                if (r_COUNT >= c_THRESHOLD_WORD)
                        o_WORD_LED <= 1'b1;
                    else if (r_COUNT >= c_THRESHOLD_LETTER) 
                        o_LETTER_LED <= 1'b1;
                    else if (r_COUNT >= c_THRESHOLD_DASH)
                        o_DASH_LED <= 1'b1;
                    else
                        o_DOT_LED <= 1'b1;
            end
        end

        EVALUATE :
        begin
            // Categorized the stored duration and shift appropriate bit into the buffer
            // Also queues the live-echo character for terminal
            if(r_COUNT < c_THRESHOLD_DASH)
            begin
                letter_buffer <= {letter_buffer[3:0], 1'b0};
                o_UART_Byte <= 8'h2E; // '.'
            end
            else if (r_COUNT < c_THRESHOLD_LETTER)
            begin
                letter_buffer <= {letter_buffer[3:0], 1'b1};
                o_UART_Byte <= 8'h2D; // '-'
            end
            else if (r_COUNT < c_THRESHOLD_WORD)
            begin
                sentence_memory[write_index] <= w_decoded_ascii;
                write_index <= write_index + 1;
                letter_buffer <= 5'b00001; // Reset Buffer
                o_UART_Byte <= 8'h20; // 'Space'
            end
            else
            begin
                sentence_memory[write_index] <= 8'h20;
                write_index <= write_index + 1;
                letter_buffer <= 5'b00001; // Reset Buffer
                o_UART_Byte <= 8'h20; // 'Space'
            end
            r_SM_Main <= ECHO_CHAR;
        end

        ECHO_CHAR :
        begin
            // Trigger UART to send live-feedback character
            o_UART_DV <= 1'b1;
            r_SM_Main <= ECHO_WAIT;
        end

        ECHO_WAIT :
        begin
            // Wait for UART Transmission to finish before returning to IDLE
            if (i_UART_Done == 1'b1)
                r_SM_Main <= IDLE;
            else
                r_SM_Main <= ECHO_WAIT;
        end

        APPEND_LF :
        begin
            // Append a Line Feed character before UART Transmission
            sentence_memory[write_index] <= 8'h0A;
            write_index <= write_index + 1;
            r_SM_Main <= TRANSMIT;
        end


        TRANSMIT :
        begin
            // Sub-state Machine: Dumps the sentence memory array to UART
            case(r_TX_State)

            TX_CHECK_INDEX : 
            begin
                // Continues to send bytes to UART
                if (read_index < write_index)
                    r_TX_State <= TX_SEND_BYTE;
                else
                begin
                    // Transmission complete: Reset pointers and return to IDLE
                    read_index <= 0;
                    write_index <= 2;
                    r_TX_State <= TX_CHECK_INDEX;
                    r_SM_Main <= IDLE;
                end
            end

            TX_SEND_BYTE :
            begin
                // Loads current letter to be sent to UART and triggers UART
                o_UART_Byte <= sentence_memory[read_index];
                o_UART_DV <= 1'b1;
                r_TX_State <= TX_WAIT_DONE;
            end

            TX_WAIT_DONE:
            begin
                // Wait for UART Transmission to finish before returning to IDLE
                // increments read_index for next letter
                if (i_UART_Done == 1'b1)
                begin
                    read_index <= read_index + 1;
                    r_TX_State <= TX_CHECK_INDEX;
                end
                else 
                    r_TX_State <= TX_WAIT_DONE;
            end
            endcase
        end
    endcase
end
endmodule