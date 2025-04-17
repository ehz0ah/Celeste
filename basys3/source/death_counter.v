`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.04.2025 19:26:29
// Design Name: 
// Module Name: death_counter
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


module death_counter (
    input clk,
    input [13:0] number, // 0 to 9999 input
    output reg [3:0] an,
    output reg [6:0] seg
);

    // Break number into digits
    reg [3:0] digit0, digit1, digit2, digit3;
    always @(*) begin
        digit0 = number % 10;
        digit1 = (number / 10) % 10;
        digit2 = (number / 100) % 10;
        digit3 = (number / 1000) % 10;
    end

    // Refresh counter for multiplexing
    reg [15:0] refresh_counter = 0;
    always @(posedge clk)
        refresh_counter <= refresh_counter + 1;

    wire [1:0] current_digit = refresh_counter[15:14];

    // Drive 7-segment
    always @(*) begin
        case (current_digit)
            2'b00: begin
                an = 4'b1110;
                seg = seg_decoder(digit0);
            end
            2'b01: begin
                an = 4'b1101;
                seg = seg_decoder(digit1);
            end
            2'b10: begin
                an = 4'b1011;
                seg = seg_decoder(digit2);
            end
            2'b11: begin
                an = 4'b0111;
                seg = seg_decoder(digit3);
            end
        endcase
    end

    // Digit to 7-segment decoder
    function [6:0] seg_decoder;
        input [3:0] num;
        begin
            case (num)
                4'd0: seg_decoder = 7'b1000000;
                4'd1: seg_decoder = 7'b1111001;
                4'd2: seg_decoder = 7'b0100100;
                4'd3: seg_decoder = 7'b0110000;
                4'd4: seg_decoder = 7'b0011001;
                4'd5: seg_decoder = 7'b0010010;
                4'd6: seg_decoder = 7'b0000010;
                4'd7: seg_decoder = 7'b1111000;
                4'd8: seg_decoder = 7'b0000000;
                4'd9: seg_decoder = 7'b0010000;
                default: seg_decoder = 7'b1111111; // blank
            endcase
        end
    endfunction

endmodule

