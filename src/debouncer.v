// debouncer.v
// Filters out mechanical switch bouncing noise using a stable-cycle counter.

module debouncer #(
    parameter COUNTER_WIDTH = 16,       // Bits needed to hold the max count
    parameter BOUNCE_LIMIT  = 50000     // Number of clock cycles the signal must remain stable
)(
    input  wire clk,
    input  wire rst_n,
    input  wire noisy_in,               // Raw, bouncing input from physical button
    output reg  debounced_out           // Clean, rock-solid output for your design
);

    // Pipeline registers to detect changes in the input signal
    reg in_reg0;
    reg in_reg1;
    
    // Counter to track continuous stability duration
    reg [COUNTER_WIDTH-1:0] stable_counter;

    // Step 1: Double-stage sampling to detect transitions safely
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_reg0 <= 1'b0;
            in_reg1 <= 1'b0;
        end else begin
            in_reg0 <= noisy_in;
            in_reg1 <= in_reg0;
        end
    end

    // Step 2: Stability validation counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stable_counter <= {COUNTER_WIDTH{1'b0}};
            debounced_out  <= 1'b0;
        end else begin
            // Look for a mismatch between the current sample and previous sample
            if (in_reg0 != in_reg1) begin
                // The signal bounced or transitioned! Reset the timer completely.
                stable_counter <= {COUNTER_WIDTH{1'b0}};
            end else if (stable_counter < BOUNCE_LIMIT-1) begin
                // The signal is sitting perfectly still. Keep counting up.
                stable_counter <= stable_counter + 1'b1;
            end else begin
                // It is officially stable. Update the output register.
                debounced_out  <= in_reg1;
            end
        end
    end

endmodule