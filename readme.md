 # Verilog Smart Elevator Controller

This project implements a 5-floor elevator controller in Verilog HDL. The design was developed as a digital design project and models the behavior of a real elevator system, including request handling, door control, overload protection, emergency operation, rush-hour modes and sleep mode.

The elevator supports Floors 0 to 4 and services both cabin requests and hall requests.

## Features

* 5-floor elevator system
* Cabin and hall request handling
* Upward and downward movement control
* Door opening, holding and closing states
* Door obstruction detection
* Overload protection with alarm
* Emergency return-to-ground operation
* Morning and evening rush modes
* Sleep mode during long inactivity
* Input synchronization and debouncing
* Self-checking testbench

## Project Structure

```
src/
├── elevator_top.v
├── elevator_fsm.v
├── request_registry.v
├── synchronizer.v
├── debouncer.v
└── elevator_defs.v

tb/
└── elevator_tb.v

waveforms/
└── waveform screenshots

docs/
└── signal_reference.md
```

## Module Overview

### elevator_top.v

Top-level module that connects all submodules.

### elevator_fsm.v

Contains the finite state machine responsible for elevator behavior.

### request_registry.v

Stores active requests and clears them after servicing.

### synchronizer.v

Synchronizes asynchronous inputs to the system clock.

### debouncer.v

Removes switch bounce from mechanical inputs.

### elevator_tb.v

Unified testbench used for verification.

## FSM States

* IDLE
* MOVE_UP
* MOVE_DOWN
* DOOR_OPENING
* DOOR_HOLD
* DOOR_CLOSING
* OVERLOAD
* SLEEP
* EMERGENCY

## Test Cases

The following scenarios were verified:

### Test 1 - Upward Cabin Requests

Requests for Floors 2 and 4 are issued and serviced in order.

### Test 2 - Downward Hall Request

A downward hall request is serviced correctly.

### Test 3 - Door Obstruction

An obstruction is applied during door closing and the door reopens.

### Test 4 - Overload Protection

The alarm is activated and the doors remain open until overload is removed.

### Test 5 - Emergency Operation

The elevator is forced to travel to the ground floor, opens the door, and remains locked until reset.

### Test 6 - Morning Rush Mode

The elevator automatically parks at the top floor when idle.

### Test 7 - Evening Rush Mode

The elevator automatically parks at the ground floor when idle.

### Test 8 - Sleep Mode

The elevator enters sleep mode after inactivity and wakes when a new request is received.

## Waveforms

Representative GTKWave captures are included in the `waveforms` folder.

The screenshots cover:

* Normal operation
* Door obstruction handling
* Overload condition
* Emergency operation
* Rush mode behavior
* Sleep mode and wake-up operation

## Simulation

Compile:

```bash
iverilog -I src -o out.vvp tb/elevator_tb.v src/*.v
```

Run:

```bash
vvp out.vvp
```

View waveform:

```bash
gtkwave elevator_tb.vcd
```

## Notes

The project focuses on digital control logic and verification. Floor movement is modeled through floor sensor inputs provided by the testbench. All timers are parameterized in the testbench.

## Author

Gaurish Juneja
