`timescale 1ns/1ps
`include "elevator_defs.v"

module elevator_tb;

    reg clk;
    reg rst_n;

    reg [4:0] raw_car_req;
    reg [4:0] raw_hall_up;
    reg [4:0] raw_hall_down;

    reg raw_overload;
    reg raw_emergency_fault;
    reg raw_door_obstruct;

    reg [4:0] floor_sensor;
    reg [1:0] rush_mode;

    wire [2:0] current_floor;
    wire direction;
    wire moving;
    wire [1:0] door_state;
    wire alarm;
    wire sleep_mode;

    integer errors;

    elevator_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .raw_car_req(raw_car_req),
        .raw_hall_up(raw_hall_up),
        .raw_hall_down(raw_hall_down),
        .raw_overload(raw_overload),
        .raw_emergency_fault(raw_emergency_fault),
        .raw_door_obstruct(raw_door_obstruct),
        .floor_sensor(floor_sensor),
        .rush_mode(rush_mode),
        .current_floor(current_floor),
        .direction(direction),
        .moving(moving),
        .door_state(door_state),
        .alarm(alarm),
        .sleep_mode(sleep_mode)
    );

    always #10 clk = ~clk;

    task check;
        input condition;
        input [1023:0] message;
        begin
            if (condition)
                $display("[PASS] %0s", message);
            else begin
                $display("[FAIL] %0s", message);
                errors = errors + 1;
            end
        end
    endtask

    task reset_system;
        begin
            rst_n = 0;
            raw_car_req = 5'b00000;
            raw_hall_up = 5'b00000;
            raw_hall_down = 5'b00000;
            raw_overload = 0;
            raw_emergency_fault = 0;
            raw_door_obstruct = 0;
            rush_mode = `MODE_NORMAL;
            floor_sensor = 5'b00001;
            #200;
            rst_n = 1;
            #200;
        end
    endtask

    task press_car;
        input integer floor;
        begin
            raw_car_req[floor] = 1'b1;
            #300;
            raw_car_req[floor] = 1'b0;
            #2000;
        end
    endtask

    task press_hall_up;
        input integer floor;
        begin
            raw_hall_up[floor] = 1'b1;
            #300;
            raw_hall_up[floor] = 1'b0;
            #2000;
        end
    endtask

    task press_hall_down;
        input integer floor;
        begin
            raw_hall_down[floor] = 1'b1;
            #300;
            raw_hall_down[floor] = 1'b0;
            #2000;
        end
    endtask

    task wait_door_state;
        input [1:0] target;
        integer t;
        begin
            t = 0;
            while (door_state != target && t < 20000) begin
                #20;
                t = t + 1;
            end
        end
    endtask

    task step_to_next_floor;
        begin
            #2000;

            if (direction && current_floor < 3'd4)
                floor_sensor = (5'b00001 << (current_floor + 1));
            else if (!direction && current_floor > 3'd0)
                floor_sensor = (5'b00001 << (current_floor - 1));

            #1000;
        end
    endtask

    initial begin
        $dumpfile("elevator_tb.vcd");
        $dumpvars(0, elevator_tb);

        clk = 0;
        errors = 0;

        // TEST 1: Upward cabin requests
        $display("\nTEST 1: UPWARD CABIN REQUESTS");
        reset_system();

        press_car(2);
        press_car(4);

        #2000;
        check(moving && direction, "Elevator starts moving UP");

        // Move automatically until Floor 2
        while (moving && current_floor != 3'd2) begin
            step_to_next_floor();
        end

        wait_door_state(2'b10);
        check(door_state == 2'b10 && current_floor == 3'd2,
            "Stops at Floor 2");

        #10000;

        // Continue automatically until Floor 4
        while (moving && current_floor != 3'd4) begin
            step_to_next_floor();
        end

        wait_door_state(2'b10);
        check(door_state == 2'b10 && current_floor == 3'd4,
            "Stops at Floor 4");

        #10000;


        // TEST 2: Downward hall request
        $display("\nTEST 2: DOWNWARD HALL REQUEST");

        press_hall_down(1);

        #2000;
        check(moving && !direction,
            "Elevator starts moving DOWN");

        // Move automatically until Floor 1
        while (moving && current_floor != 3'd1) begin
            step_to_next_floor();
        end

        wait_door_state(2'b10);
        check(door_state == 2'b10 && current_floor == 3'd1,
            "Stops at Floor 1");

        #10000;


        // TEST 3: Door obstruction during closing
        $display("\nTEST 3: DOOR OBSTRUCTION");

        // Current floor is already Floor 1 from Test 2.
        // Create a fresh current-floor door cycle.
        press_hall_up(1);

        wait_door_state(2'b11);

        raw_door_obstruct = 1'b1;
        #3000;

        check(door_state == 2'b01 || door_state == 2'b10,
            "Door reverses/reopens because obstruction occurred during closing");

        raw_door_obstruct = 1'b0;
        #10000;


        // TEST 4: Overload
        $display("\nTEST 4: OVERLOAD");

        press_car(3);

        #2000;
        check(moving && direction,
            "Elevator starts moving UP toward Floor 3");

        // Move automatically until Floor 3
        while (moving && current_floor != 3'd3) begin
            step_to_next_floor();
        end

        wait_door_state(2'b10);

        raw_overload = 1'b1;
        #3000;

        check(alarm && door_state == 2'b10,
            "Overload keeps door open and alarm ON");

        raw_overload = 1'b0;
        #3000;

        check(!alarm,
            "Alarm clears after overload removed");

        #10000;

        // TEST 5: Emergency return-to-ground
        $display("\nTEST 5: EMERGENCY RETURN TO GROUND");


        floor_sensor = 5'b01000;   // Floor 3
        #1000;

        press_car(4);

        #2000;
        check(moving && direction,
              "Elevator starts moving UP before emergency");

        raw_emergency_fault = 1'b1;
        #2000;

        check(alarm && moving && !direction,
              "Emergency active: alarm ON and elevator forced DOWN");

        while (current_floor > 3'd0) begin
            step_to_next_floor();
        end

        check(current_floor == 3'd0,
              "Elevator reached ground floor during emergency");

        wait_door_state(2'b10);

        check(alarm && !moving && door_state == 2'b10,
              "Emergency: door opened at ground floor");

        wait_door_state(2'b00);
        #2000;

        check(alarm && !moving && door_state == 2'b00,
              "Emergency lockout active at ground after door closes");

        raw_emergency_fault = 1'b0;
        #2000;

        check(alarm && !moving,
              "Emergency remains locked after button release");

        reset_system();

        check(!alarm && !moving && current_floor == 3'd0,
              "Reset clears emergency and controller starts from ground floor");

        // TEST 6: Morning rush homing
        $display("\nTEST 6: MORNING RUSH HOMING");


        rush_mode = `MODE_MORNING;

        #50000;
        check(moving && direction,
              "Morning mode moves empty elevator UP");

        while (moving && direction && current_floor < 3'd4) begin
            step_to_next_floor();
        end

        #2000;
        check(current_floor == 3'd4 && !moving,
              "Morning homing reaches top floor and stops");

        // TEST 7: Evening rush homing
        $display("\nTEST 7: EVENING RUSH HOMING");



        rush_mode = `MODE_EVENING;

        #50000;
        check(moving && !direction,
              "Evening mode moves empty elevator DOWN");

        while (moving && !direction && current_floor > 3'd0) begin
            step_to_next_floor();
        end

        #2000;
        check(current_floor == 3'd0 && !moving,
              "Evening homing reaches ground floor and stops");

        // TEST 8: Sleep mode
        $display("\nTEST 8: SLEEP MODE");

        rush_mode = `MODE_NORMAL;

        #220000;
        check(sleep_mode,
            "Elevator enters sleep mode after inactivity");

        // Wake-up request from Floor 3
        press_hall_up(3);

        #2000;

        check(!sleep_mode,
            "Elevator wakes after request");

        check(moving && direction,
            "Elevator starts moving UP after wake-up");

        // Travel automatically until Floor 3 is reached
        while (moving && current_floor != 3'd3) begin
            step_to_next_floor();
        end

        wait_door_state(2'b10);

        check(current_floor == 3'd3 &&
            door_state == 2'b10,
            "Elevator reaches Floor 3 and opens door");

        wait_door_state(2'b11);

        check(door_state == 2'b11,
            "Door begins closing at Floor 3");

        #10000;

        check(!moving &&
            door_state == 2'b00,
            "Elevator completes service and returns to idle");

        $display("\nTEST SUMMARY");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TESTS FAILED", errors);

        $finish;
    end

endmodule