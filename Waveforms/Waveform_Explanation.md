# Waveform Reference and Test Results

This folder contains GTKWave screenshots used to verify the functionality of the Smart Elevator Controller.

## Important Signals

### floor_sensor

The elevator position input provided by the testbench.

This signal is **one-hot encoded**:

| Floor   | floor_sensor |
| ------- | ------------ |
| Floor 0 | 00001        |
| Floor 1 | 00010        |
| Floor 2 | 00100        |
| Floor 3 | 01000        |
| Floor 4 | 10000        |

When the elevator is travelling between floors, `floor_sensor` becomes `00000`.

---

### current_floor

Current floor decoded by the controller from the floor sensor input.

Unlike `floor_sensor`, this signal is stored as a binary floor number.

Example:

| Floor   | current_floor |
| ------- | ------------- |
| Floor 0 | 0             |
| Floor 1 | 1             |
| Floor 2 | 2             |
| Floor 3 | 3             |
| Floor 4 | 4             |

---

### raw_car_req

Raw cabin button inputs.

These represent button presses made from inside the elevator before synchronization and debouncing.

---

### car_req_reg

Registered cabin requests after synchronization and debouncing.

This signal is used internally by the controller and demonstrates successful input conditioning.

---

### raw_hall_up

Raw UP hall call inputs.

Represents passengers calling the elevator from a floor and requesting upward travel.

---

### hall_up_reg

Debounced and registered version of `raw_hall_up`.

Used by the controller for decision making.

---

### raw_hall_down

Raw DOWN hall call inputs.

Represents passengers calling the elevator from a floor and requesting downward travel.

---

### hall_down_reg

Debounced and registered version of `raw_hall_down`.

Used by the controller after input conditioning.

---

### door_state

Represents the current door operation state.

| Value | Meaning        |
| ----- | -------------- |
| 00    | Door Closed    |
| 01    | Door Opening   |
| 10    | Door Hold/Open |
| 11    | Door Closing   |

---

### rush_mode

Operating mode of the elevator.

| Value | Mode              |
| ----- | ----------------- |
| 00    | Normal Mode       |
| 01    | Morning Rush Mode |
| 10    | Evening Rush Mode |

#### Morning Rush Mode

If the elevator remains idle for a long duration with no pending requests, it automatically moves to the top floor.

This simulates office buildings where passengers are expected to arrive and travel upwards during the morning.

#### Evening Rush Mode

If the elevator remains idle for a long duration with no pending requests, it automatically moves to the ground floor.

This simulates office buildings where passengers are expected to leave and travel downwards during the evening.

---

### moving

Indicates whether the elevator is currently travelling between floors.

---

### direction

Travel direction of the elevator.

| Value | Meaning |
| ----- | ------- |
| 0     | Down    |
| 1     | Up      |

---

### alarm

Activated during overload and emergency conditions.

---

### sleep_mode

Indicates that the elevator has entered power-saving mode after prolonged inactivity.

---

# Waveform Descriptions

## Waveform 1

Base case showing the initial state of the elevator after reset.

---

## Waveforms 2-3

Input registration after synchronization and debouncing.

Raw inputs are filtered and transferred into the registered request signals.

---

## Waveforms 4-5

Elevator receives requests for Floors 2 and 4.

The elevator moves upward to Floor 2 and performs the complete door sequence.

---

## Waveform 6

Door closes and the elevator resumes upward movement toward the next request.

---

## Waveforms 7-8

Elevator reaches Floor 4 and performs the complete door sequence.

**Test 1 Complete**

---

## Waveform 9

Test 2 begins.

The elevator receives a hall request from Floor 1 and starts moving downward.

---

## Waveforms 10-11

Elevator reaches Floor 1 and services the request.

**Test 2 Complete**

---

## Waveforms 12-13

Door Obstruction Test.

An obstruction is applied while the door is closing.

The controller immediately reopens the door and keeps it open until the obstruction is removed.

**Test 3 Complete**

---

## Waveform 14

Elevator receives a request for Floor 3.

---

## Waveform 15

Overload Protection Test.

An overload condition is applied.

The alarm is activated and the door remains open while overload persists.

Once the overload is removed, normal operation resumes.

**Test 4 Complete**

---

## Waveform 16

Elevator receives a request for Floor 4.

---

## Waveform 17

Emergency Test.

An emergency signal is applied while the elevator is operating.

The controller ignores existing requests and forces the elevator to return to the ground floor.

---

## Waveform 18

The elevator reaches the ground floor.

Doors open and close normally.

The controller remains locked in the emergency state until reset.

---

## Waveform 19

System reset is applied.

The controller resumes normal operation.

Morning Rush Mode is enabled.

**Test 5 Complete**

---

## Waveform 20

Morning Rush Mode.

With no pending requests and prolonged inactivity, the elevator automatically moves toward Floor 4.

---

## Waveform 21

Elevator reaches Floor 4 and remains parked.

**Test 6 Complete**

---

## Waveforms 22-23

Evening Rush Mode.

The elevator automatically returns to the ground floor after remaining idle.

**Test 7 Complete**

---

## Waveform 24

Sleep Mode Test.

After a long period of inactivity, the elevator enters power-saving mode.

---

## Waveforms 25-26

A new request is received while the elevator is sleeping.

The controller exits sleep mode and resumes normal operation.

**Test 8 Complete**
