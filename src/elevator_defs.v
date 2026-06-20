// elevator_defs.v
// Central repository for FSM states and Rush Mode constants

`ifndef ELEVATOR_DEFS_V
`define ELEVATOR_DEFS_V

// FSM State Encodings (Using 4-bit Binary)
`define STATE_IDLE         4'b0000
`define STATE_DOOR_OPENING 4'b0001
`define STATE_DOOR_HOLD    4'b0010
`define STATE_DOOR_CLOSING 4'b0011
`define STATE_MOVE_UP      4'b0100
`define STATE_MOVE_DOWN    4'b0101
`define STATE_EMERGENCY    4'b0110
`define STATE_SLEEP        4'b0111
`define STATE_OVERLOAD     4'b1000

// Rush Mode Configurations
`define MODE_NORMAL        2'b00
`define MODE_MORNING       2'b01
`define MODE_EVENING       2'b10

`endif