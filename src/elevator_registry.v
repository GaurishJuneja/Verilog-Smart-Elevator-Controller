// elevator_registry.v
// Robust Input Request Latching & Look-Ahead Flag Compilation Registry.
// Employs synchronous set/clear prioritization and safe bounds index tracking.

`include "elevator_defs.v"


module elevator_registry (
    input  wire        clk,
    input  wire        rst_n,
    
    // Asynchronous Momentary User Button Inputs
    input  wire [4:0]  car_req,              // Internal cabin floor selection buttons
    input  wire [4:0]  hall_up,              // Hallway up-arrow request buttons
    input  wire [4:0]  hall_down,            // Hallway down-arrow request buttons
    
    // Synchronous Flushes sent from the FSM on arrival
    input  wire [4:0]  clear_car_req,
    input  wire [4:0]  clear_hall_up,
    input  wire [4:0]  clear_hall_down,
    
    // State Feedback from Datapath
    input  wire [2:0]  current_floor,        // Current tracking position (0 to 4)
    
    // High-Level Filtered Flags fed back to FSM Combinational Look-Ahead Path
    output reg         any_req_above,        // True if any request exists on floors higher than current
    output reg         any_req_below,        // True if any request exists on floors lower than current
    output reg         req_at_current_floor, // True if a target request is waiting right now
    output reg         car_passenger_onboard // True if any internal cabin request is pending
);

    // Internal Memory Banks tracking pending requests per floor
    reg [4:0] car_req_reg;
    reg [4:0] hall_up_reg;
    reg [4:0] hall_down_reg;

    reg [4:0] car_req_prev;
    reg [4:0] hall_up_prev;
    reg [4:0] hall_down_prev;

    wire [4:0] car_req_pulse;
    wire [4:0] hall_up_pulse;
    wire [4:0] hall_down_pulse;

    assign car_req_pulse   = car_req   & ~car_req_prev;
    assign hall_up_pulse   = hall_up   & ~hall_up_prev;
    assign hall_down_pulse = hall_down & ~hall_down_prev;

    integer i;

   
    // BLOCK 1: SEQUENTIAL REQUEST MEMORY LATCHING (Set/Clear Logic)
   
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            car_req_reg   <= 5'b00000;
            hall_up_reg   <= 5'b00000;
            hall_down_reg <= 5'b00000;

            car_req_prev   <= 5'b00000;
            hall_up_prev   <= 5'b00000;
            hall_down_prev <= 5'b00000;
        end else begin
            car_req_prev   <= car_req;
            hall_up_prev   <= hall_up;
            hall_down_prev <= hall_down;
            for (i = 0; i < 5; i = i + 1) begin
                
                // 1. Cabin Calls Latching Array
                if (clear_car_req[i]) begin
                    car_req_reg[i] <= 1'b0; // FSM Clear command takes absolute priority
                end else if (car_req_pulse[i]) begin
                    car_req_reg[i] <= 1'b1; // Latch momentary passenger press
                end

                // 2. Hall Up Calls Latching Array
                if (clear_hall_up[i]) begin
                    hall_up_reg[i] <= 1'b0;
                end else if (hall_up_pulse[i]) begin
                    hall_up_reg[i] <= 1'b1;
                end

                // 3. Hall Down Calls Latching Array
                if (clear_hall_down[i]) begin
                    hall_down_reg[i] <= 1'b0;
                end else if (hall_down_pulse[i]) begin
                    hall_down_reg[i] <= 1'b1;
                end
                
            end
        end
    end

  
    // BLOCK 2: COMBINATIONAL LOOK-AHEAD FLAG GENERATION
    always @(*) begin
        
        car_passenger_onboard = |car_req_reg; 

        //Initialization to prevent Latch Inferences
        req_at_current_floor = 1'b0;
        any_req_above        = 1'b0;
        any_req_below        = 1'b0;

        // Vector Check Arrays mapped to current floor layout
        case (current_floor)
            3'd0: begin
                req_at_current_floor = car_req_reg[0] || hall_up_reg[0] || hall_down_reg[0];
                any_req_above        = |car_req_reg[4:1] || |hall_up_reg[4:1] || |hall_down_reg[4:1];
                any_req_below        = 1'b0; // Base floor bounds check
            end

            3'd1: begin
                req_at_current_floor = car_req_reg[1] || hall_up_reg[1] || hall_down_reg[1];
                any_req_above        = |car_req_reg[4:2] || |hall_up_reg[4:2] || |hall_down_reg[4:2];
                any_req_below        = car_req_reg[0]    || hall_up_reg[0]    || hall_down_reg[0];
            end

            3'd2: begin
                req_at_current_floor = car_req_reg[2] || hall_up_reg[2] || hall_down_reg[2];
                any_req_above        = |car_req_reg[4:3] || |hall_up_reg[4:3] || |hall_down_reg[4:3];
                any_req_below        = |car_req_reg[1:0] || |hall_up_reg[1:0] || |hall_down_reg[1:0];
            end

            3'd3: begin
                req_at_current_floor = car_req_reg[3] || hall_up_reg[3] || hall_down_reg[3];
                any_req_above        = car_req_reg[4]    || hall_up_reg[4]    || hall_down_reg[4];
                any_req_below        = |car_req_reg[2:0] || |hall_up_reg[2:0] || |hall_down_reg[2:0];
            end

            3'd4: begin
                req_at_current_floor = car_req_reg[4] || hall_up_reg[4] || hall_down_reg[4];
                any_req_above        = 1'b0; // Top floor bounds check
                any_req_below        = |car_req_reg[3:0] || |hall_up_reg[3:0] || |hall_down_reg[3:0];
            end

            default: begin
                //For uninitialized/X state tracking hazards
                req_at_current_floor = 1'b0;
                any_req_above        = 1'b0;
                any_req_below        = 1'b0;
            end
        endcase
    end

endmodule