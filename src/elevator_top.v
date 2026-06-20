// elevator_top.v
// Top-Level Structural Wrapper for the Hostel FSM Elevator System.
// Integrates Input Synchronization, Debouncing, Request Memory, and the FSM Controller.

`include "elevator_defs.v"

module elevator_top #(
    parameter DEBOUNCE_LIMIT =50000
) (
    input  wire        clk,                  // System Master Clock
    input  wire        rst_n,                // Active-low asynchronous reset
    
    // Raw Asynchronous External Hardware Inputs (Buttons & Switches)
    input  wire [4:0]  raw_car_req,          // Unfiltered internal cabin panel button presses
    input  wire [4:0]  raw_hall_up,          // Unfiltered hallway up buttons
    input  wire [4:0]  raw_hall_down,        // Unfiltered hallway down buttons
    
    input  wire        raw_overload,         // Unfiltered weight sensor threshold flag
    input  wire        raw_emergency_fault,  // Unfiltered E-stop physical button
    input  wire        raw_door_obstruct,    // Unfiltered door IR proximity sensor
    
    // Physical Position Feedback
    input  wire [4:0]  floor_sensor,         // One-hot physical floor proximity limit switches
    
    // Environment Configuration Switch
    input  wire [1:0]  rush_mode,            // Evaluates current timeline parameters (Morning/Evening)
    
    // System Status Hardware Outputs
    output wire [2:0]  current_floor,        // 3-bit binary floor position (0 to 4)
    output wire        direction,            // 1'b1 = UP, 1'b0 = DOWN
    output wire        moving,               // 1'b1 = Motor active, 1'b0 = Stationary
    output wire [1:0]  door_state,           // 00=Closed, 01=Opening, 10=Open/Hold, 11=Closing
    output wire        alarm,                // Active-high emergency warning siren
    output wire        sleep_mode            // Active-high energy conservation flag
);

    // 1. INTERNAL WIRE DECLARATIONS
    
    // Unified 15-bit arrays to handle user button generation loops
    wire [14:0] raw_buttons;
    wire [14:0] clean_buttons;
    
    // Decoupled clean button busses
    wire [4:0]  clean_car_req;
    wire [4:0]  clean_hall_up;
    wire [4:0]  clean_hall_down;
    
    // Synchronized but un-debounced floor sensor bus
    wire [4:0]  clean_floor_sensor;
    
    // Clean, synchronized safety sensor lines
    wire        clean_overload;
    wire        clean_emergency_fault;
    wire        clean_door_obstruct;

    // FSM to Registry Look-Ahead Evaluation Variables
    wire        any_req_above;
    wire        any_req_below;
    wire        req_at_current_floor;
    wire        car_passenger_onboard;

    // FSM to Registry Memory Clearance Vectors
    wire [4:0]  clear_car_req;
    wire [4:0]  clear_hall_up;
    wire [4:0]  clear_hall_down;

    // Pack the separate user floor buttons into a unified 15-bit array for clean mapping
    assign raw_buttons = {raw_car_req, raw_hall_up, raw_hall_down};
    
    // Unpack the cleaned 15-bit array back into individual floor tracking buses
    assign {clean_car_req, clean_hall_up, clean_hall_down} = clean_buttons;


    
    // 2. PARALLEL GENERATE PIPELINES & CONDITIONING
    
    
    genvar k;
    generate
        // Pipeline Array 1: Human Buttons (Synchronized AND Debounced)
        for (k = 0; k < 15; k = k + 1) begin : gen_button_conditioning
            wire button_sync_to_debounce;

            synchronizer u_btn_sync (
                .clk     (clk),
                .rst_n   (rst_n),
                .async_in(raw_buttons[k]),
                .sync_out(button_sync_to_debounce)
            );

            debouncer #(
                .COUNTER_WIDTH(4),
                .BOUNCE_LIMIT(5)
            ) u_btn_debounce (
                .clk          (clk),
                .rst_n        (rst_n),
                .noisy_in     (button_sync_to_debounce),
                .debounced_out(clean_buttons[k])
            );
        end
    endgenerate

    genvar f;
    generate
        // Pipeline Array 2: Floor Sensors (Synchronized ONLY for zero-latency tracking)
        for (f = 0; f < 5; f = f + 1) begin : gen_floor_conditioning
            synchronizer u_floor_sync (
                .clk     (clk),
                .rst_n   (rst_n),
                .async_in(floor_sensor[f]),
                .sync_out(clean_floor_sensor[f])
            );
        end
    endgenerate

    // Dedicated single-bit synchronizer
    synchronizer u_overload_sync (
        .clk     (clk),
        .rst_n   (rst_n),
        .async_in(raw_overload),
        .sync_out(clean_overload)
    );

    synchronizer u_emergency_sync (
        .clk     (clk),
        .rst_n   (rst_n),
        .async_in(raw_emergency_fault),
        .sync_out(clean_emergency_fault)
    );

    synchronizer u_obstruct_sync (
        .clk     (clk),
        .rst_n   (rst_n),
        .async_in(raw_door_obstruct),
        .sync_out(clean_door_obstruct)
    );



    // 3. CORE SUBMODULE INSTANTIATIONS
 

    // The Request Memory Registry module
    elevator_registry u_registry (
        .clk                  (clk),
        .rst_n                (rst_n),
        
        // Inputs from conditioned external buttons
        .car_req              (clean_car_req),
        .hall_up              (clean_hall_up),
        .hall_down            (clean_hall_down),
        
        // Feedback clear commands coming out of the FSM
        .clear_car_req        (clear_car_req),
        .clear_hall_up        (clear_hall_up),
        .clear_hall_down      (clear_hall_down),
        
        // Datapath feedback tracking
        .current_floor        (current_floor),
        
        // High-level filtered look-ahead outputs fed forward to the FSM
        .any_req_above        (any_req_above),
        .any_req_below        (any_req_below),
        .req_at_current_floor (req_at_current_floor),
        .car_passenger_onboard(car_passenger_onboard)
    );

    // FSM controller
    elevator_fsm u_fsm (
        .clk                  (clk),
        .rst_n                (rst_n),
        
        // Conditioned Safety & Physical Sensor Inputs
        .overload             (clean_overload),
        .emergency_fault      (clean_emergency_fault),
        .door_obstruct        (clean_door_obstruct),
        .floor_sensor         (clean_floor_sensor),
        
        // Configuration Environment Setting
        .rush_mode            (rush_mode),
        
        // Look-Ahead Filtered Flag inputs from the Registry
        .any_req_above        (any_req_above),
        .any_req_below        (any_req_below),
        .req_at_current_floor (req_at_current_floor),
        .car_passenger_onboard(car_passenger_onboard),
        
        // Feedback clearance output vectors to wipe the Registry memory slots
        .clear_car_req        (clear_car_req),
        .clear_hall_up        (clear_hall_up),
        .clear_hall_down      (clear_hall_down),
        
        // Hardware Status Top-Level System Driving Outputs
        .current_floor        (current_floor),
        .direction            (direction),
        .moving               (moving),
        .door_state           (door_state),
        .alarm                (alarm),
        .sleep_mode           (sleep_mode)
    );

endmodule