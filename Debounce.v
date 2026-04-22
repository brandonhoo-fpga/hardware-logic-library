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
    input i_Clk,
    input i_Switch,
    output o_Switch
);

parameter c_DEBOUNCE_LIMIT = 250000;

reg[17:0] r_Count = 0;
reg r_State = 1'b0;

always @(posedge i_Clk)
begin
    if (i_Switch != r_State && r_Count < c_DEBOUNCE_LIMIT)
    r_Count <= r_Count + 1;

    else if (r_Count == c_DEBOUNCE_LIMIT)
    begin
    r_State <= i_Switch;
    r_Count <= 0;
    end

    else
    r_Count <= 0;
end

assign o_Switch = r_State;

endmodule
