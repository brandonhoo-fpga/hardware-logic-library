// ============================================================================
// File Name   : Debounce.v   
// Author      : Brandon Hoo
// Description : State-based debouncer for mechanical switches and buttons.
//               Filters out mechanical bounce by requiring the input state to
//               remain stable for c_DEBOUNCE_LIMIT clock cycles before updating
//               the output state.

//               Note: Default limit (250,000) provides an optimal 10ms delay
//               when driven by a 25MHz clock (e.g. Nandland Go Board)
// ============================================================================

module Debounce (
    input i_Clk,    // 25MHz system clock
    input i_Switch, // Switch Input   
    output o_Switch // Switch Output
);

// 25MHz clock = 40ns per clock cycle
// 10ms / 40ns = 250000 cycles = c_DEBOUNCE_LIMIT
parameter c_DEBOUNCE_LIMIT = 250000;

// 18-bit counter -> 2^18 = 262,144
reg[17:0] r_Count = 0;
reg r_State = 1'b0;

always @(posedge i_Clk)
begin
    // The physical switch differs from our r_State, indicates potential press
    // Increments counter as long as c_DEBOUNCE_LIMIT hasn't been reached
    if (i_Switch != r_State && r_Count < c_DEBOUNCE_LIMIT)
    r_Count <= r_Count + 1;

    // The counter has reached c_DEBOUNCE_LIMIT, apply valid state change and reset count
    else if (r_Count == c_DEBOUNCE_LIMIT)
    begin
    r_State <= i_Switch;
    r_Count <= 0;
    end

    // No switch activity, reset counter
    else
    r_Count <= 0;
end

// Drives the output port with the debounced register state
assign o_Switch = r_State;