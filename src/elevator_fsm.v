// elevator_fsm.v

`include "elevator_defs.v"

module elevator_fsm (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        overload,
    input  wire        emergency_fault,
    input  wire        door_obstruct,
    input  wire [4:0]  floor_sensor,

    input  wire [1:0]  rush_mode,

    input  wire        any_req_above,
    input  wire        any_req_below,
    input  wire        req_at_current_floor,
    input  wire        car_passenger_onboard,

    output reg  [4:0]  clear_car_req,
    output reg  [4:0]  clear_hall_up,
    output reg  [4:0]  clear_hall_down,

    output reg  [2:0]  current_floor,
    output reg         direction,
    output reg         moving,
    output reg  [1:0]  door_state,
    output reg         alarm,
    output reg         sleep_mode
);

    reg [3:0] current_state;
    reg [3:0] next_state;

    reg emergency_active;

    reg [7:0]   door_timer;
    reg [15:0]  sleep_timer;

    localparam DOOR_TIME  = 8'd50;
    localparam PARK_TIME  = 16'd2000;
    localparam SLEEP_TIME = 16'd10000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state    <= `STATE_IDLE;
            emergency_active <= 1'b0;
        end else begin
            current_state <= next_state;

            if (emergency_fault)
                emergency_active <= 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_floor <= 3'd0;
            direction     <= 1'b1;
            door_timer    <= 8'd0;
            sleep_timer   <= 16'd0;
        end else begin

            if (floor_sensor[0])      current_floor <= 3'd0;
            else if (floor_sensor[1]) current_floor <= 3'd1;
            else if (floor_sensor[2]) current_floor <= 3'd2;
            else if (floor_sensor[3]) current_floor <= 3'd3;
            else if (floor_sensor[4]) current_floor <= 3'd4;

            if (current_state == `STATE_MOVE_UP)
                direction <= 1'b1;
            else if (current_state == `STATE_MOVE_DOWN)
                direction <= 1'b0;

            if (current_state != next_state) begin
                door_timer <= 8'd0;
            end
            else if (current_state == `STATE_DOOR_OPENING ||
                     current_state == `STATE_DOOR_HOLD    ||
                     current_state == `STATE_DOOR_CLOSING) begin
                if (door_timer < DOOR_TIME)
                    door_timer <= door_timer + 1'b1;
            end
            else begin
                door_timer <= 8'd0;
            end

            if (current_state == `STATE_DOOR_OPENING ||
                current_state == `STATE_DOOR_HOLD    ||
                current_state == `STATE_DOOR_CLOSING) begin
                sleep_timer <= 16'd0;
            end
            else if (current_state == `STATE_IDLE) begin
                if (sleep_timer < SLEEP_TIME)
                    sleep_timer <= sleep_timer + 1'b1;
            end
        end
    end

    always @(*) begin
        next_state      = current_state;
        moving          = 1'b0;
        door_state      = 2'b00;
        alarm           = emergency_fault || emergency_active || (current_state == `STATE_EMERGENCY);
        sleep_mode      = 1'b0;
        clear_car_req   = 5'b00000;
        clear_hall_up   = 5'b00000;
        clear_hall_down = 5'b00000;

        case (current_state)

            `STATE_IDLE: begin
                if (emergency_fault || emergency_active) begin
                    if (current_floor == 3'd0)
                        next_state = `STATE_DOOR_OPENING;
                    else
                        next_state = `STATE_MOVE_DOWN;
                end
                else if (req_at_current_floor) begin
                    next_state = `STATE_DOOR_OPENING;
                end
                else if (direction == 1'b1 && any_req_above) begin
                    next_state = `STATE_MOVE_UP;
                end
                else if (direction == 1'b0 && any_req_below) begin
                    next_state = `STATE_MOVE_DOWN;
                end
                else if (any_req_above) begin
                    next_state = `STATE_MOVE_UP;
                end
                else if (any_req_below) begin
                    next_state = `STATE_MOVE_DOWN;
                end
                else if (!car_passenger_onboard &&
                         sleep_timer >= PARK_TIME &&
                         sleep_timer < SLEEP_TIME) begin
                    if (rush_mode == `MODE_MORNING && current_floor < 3'd4)
                        next_state = `STATE_MOVE_UP;
                    else if (rush_mode == `MODE_EVENING && current_floor > 3'd0)
                        next_state = `STATE_MOVE_DOWN;
                end
                else if (!car_passenger_onboard && sleep_timer >= SLEEP_TIME) begin
                    next_state = `STATE_SLEEP;
                end
            end

            `STATE_SLEEP: begin
                sleep_mode = 1'b1;

                if (emergency_fault || emergency_active) begin
                    if (current_floor == 3'd0)
                        next_state = `STATE_DOOR_OPENING;
                    else
                        next_state = `STATE_MOVE_DOWN;
                end
                else if (req_at_current_floor || any_req_above || any_req_below)
                    next_state = `STATE_IDLE;
            end

            `STATE_DOOR_OPENING: begin
                door_state = 2'b01;

                if (door_timer >= DOOR_TIME)
                    next_state = `STATE_DOOR_HOLD;
            end

            `STATE_DOOR_HOLD: begin
                door_state = 2'b10;

                if (current_floor < 3'd5) begin
                    clear_car_req[current_floor]   = 1'b1;
                    clear_hall_up[current_floor]   = 1'b1;
                    clear_hall_down[current_floor] = 1'b1;
                end

                if (overload) begin
                    next_state = `STATE_OVERLOAD;
                end
                else if (door_timer >= DOOR_TIME) begin
                    next_state = `STATE_DOOR_CLOSING;
                end
            end

            `STATE_OVERLOAD: begin
                door_state = 2'b10;
                alarm      = 1'b1;

                if (!overload)
                    next_state = `STATE_DOOR_HOLD;
            end

            `STATE_DOOR_CLOSING: begin
                door_state = 2'b11;

                if (overload || door_obstruct) begin
                    next_state = `STATE_DOOR_OPENING;
                end
                else if (door_timer >= DOOR_TIME) begin
                    if (emergency_fault || emergency_active) begin
                        if (current_floor == 3'd0)
                            next_state = `STATE_EMERGENCY;
                        else
                            next_state = `STATE_MOVE_DOWN;
                    end
                    else begin
                        next_state = `STATE_IDLE;
                    end
                end
            end

            `STATE_MOVE_UP: begin
                moving = 1'b1;

                if (emergency_fault || emergency_active) begin
                    next_state = `STATE_MOVE_DOWN;
                end
                else if (floor_sensor[current_floor]) begin
                    if (req_at_current_floor) begin
                        next_state = `STATE_DOOR_OPENING;
                    end
                    else if (!any_req_above &&
                             !(rush_mode == `MODE_MORNING &&
                               current_floor < 3'd4 &&
                               !car_passenger_onboard)) begin
                        next_state = `STATE_IDLE;
                    end
                end
            end

            `STATE_MOVE_DOWN: begin
                moving = 1'b1;

                if (emergency_fault || emergency_active) begin
                    if (current_floor == 3'd0 && floor_sensor[0])
                        next_state = `STATE_DOOR_OPENING;
                    else
                        next_state = `STATE_MOVE_DOWN;
                end
                else if (floor_sensor[current_floor]) begin
                    if (req_at_current_floor) begin
                        next_state = `STATE_DOOR_OPENING;
                    end
                    else if (!any_req_below &&
                             !(rush_mode == `MODE_EVENING &&
                               current_floor > 3'd0 &&
                               !car_passenger_onboard)) begin
                        next_state = `STATE_IDLE;
                    end
                end
            end

            `STATE_EMERGENCY: begin
                alarm      = 1'b1;
                moving     = 1'b0;
                door_state = 2'b00;
                next_state = `STATE_EMERGENCY;
            end

            default: begin
                next_state = `STATE_IDLE;
            end

        endcase
    end

endmodule