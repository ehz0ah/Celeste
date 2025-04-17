`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.04.2025 10:10:15
// Design Name: 
// Module Name: controller_input
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


module controller_input(
    input clk,              // 100 MHz
    input uart_rx,          // From ESP32 RX (JA[0])
    output leftBtn,
    output rightBtn,
    output upBtn,
    output downBtn,
    output jumpBtn,
    output dashBtn,
    output yBtn,
    output controllerConnected
    );
    
    wire [7:0] rx_data;
    wire valid;
    wire btnL;
    wire btnR;
        
    uart_rx uart (
        .clk(clk),
        .rx(uart_rx),
        .data(rx_data),
        .valid(valid)
    );

    // Keep track of which byte we're receiving
    reg [1:0] byte_count = 0;
    reg [7:0] buttons = 0;
    
    assign btnL = buttons[2];
    assign btnR = buttons[3];

    always @(posedge clk) begin
        if (valid) begin
            case (byte_count)
                0: begin
                    buttons <= rx_data;
                    byte_count <= 0;
                end
                default: byte_count <= 0;
            endcase
        end
    end
    
    // Light LED[0] if any button is pressed
    assign jumpBtn = buttons[0]; // A, PS4: ?
    assign dashBtn = buttons[1]; // X, PS4: ?
    assign leftBtn = buttons[2]; // Left
    assign rightBtn = buttons[3]; // Right
    assign upBtn = buttons[4]; // Up
    assign downBtn = buttons[5]; // Down
    assign yBtn = buttons[6]; // Y (Xbox), ? (PS4)
    assign controllerConnected = buttons[7];
    
endmodule
