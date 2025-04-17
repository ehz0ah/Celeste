`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.04.2025 14:48:16
// Design Name: 
// Module Name: dash_leds
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dash_leds (
    input clk,                   // 100 MHz
    input dash_trigger,          // 1-cycle pulse to start dash
    input player_facing_left,    // Direction of dash
    output reg [15:0] led        // LEDs 0 to 15
);

    // Clock divider for ~80Hz animation
    reg [22:0] clk_div = 0;
    wire slow_clk = clk_div[19];
    
    always @(posedge clk)
        clk_div <= clk_div + 1;


    // FSM states
    parameter IDLE = 2'd0,
              TURNING_OFF = 2'd1,
              TURNING_ON  = 2'd2;

    reg [1:0] state = IDLE;
    reg [3:0] index = 0;
    reg dir = 0;

    always @(posedge slow_clk) begin
        case (state)
            IDLE: begin
                led <= 16'b1111111111111111;
                index <= 0;
                if (dash_trigger) begin
                    dir <= player_facing_left;
                    state <= TURNING_OFF;
                end
            end

            TURNING_OFF: begin
                if (dir == 1)
                    led[index] <= 0;        // Left to right
                else
                    led[15 - index] <= 0;   // Right to left

                index <= index + 1;
                if (index == 15)
                    state <= TURNING_ON;
            end

            TURNING_ON: begin
                if (dir == 1)
                    led[index] <= 1;
                else
                    led[15 - index] <= 1;

                index <= index + 1;
                if (index == 15)
                    state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end

endmodule
