`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.04.2025 14:45:12
// Design Name: 
// Module Name: dash_input_controller
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


module dash_input_controller (
    input clk100hz,
    input basys_3_clock,
    input leftBtn,
    input rightBtn,
    input dashBtn,
    output [15:0] led
    );
    
    reg dash_prev_slow = 0;
    wire dash_pulse;
    reg player_facing_left = 0;
    
    //Determine the direction of the dash based on where player is facing (dependant on last input by user)    
    always @(posedge basys_3_clock) begin
        if (leftBtn)
            player_facing_left <= 1;
        else if (rightBtn)
            player_facing_left <= 0;
    end

    //Update the dash_pulse which is set to 1 when the user does a dash   
    always @(posedge clk100hz) begin
        dash_prev_slow <= dashBtn;
    end
    
    assign dash_pulse = dashBtn & ~dash_prev_slow;
    
    
    //Extend teh dash pulse so that it is not missed by the clock in the dash_leds module
    reg [22:0] pulse_timer = 0;
    reg dash_trigger = 0;
    
    always @(posedge basys_3_clock) begin
        if (dash_pulse) begin
            pulse_timer <= 23'd5_000_000; // ?50ms at 100MHz
            dash_trigger <= 1;
        end else if (pulse_timer > 0) begin
            pulse_timer <= pulse_timer - 1;
            dash_trigger <= 1;
        end else begin
            dash_trigger <= 0;
        end
    end
    
    //Does the dash effect (direction depends on the players position)  
    dash_leds dash_ui (
        .clk(basys_3_clock),
        .dash_trigger(dash_trigger),
        .player_facing_left(player_facing_left),
        .led(led)
    );

endmodule
