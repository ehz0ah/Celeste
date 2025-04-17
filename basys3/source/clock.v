`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.03.2025 21:41:23
// Design Name: 
// Module Name: clock
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


module clock(input CLOCK, [31:0]m, output reg OUT_CLOCK = 0);
    reg [31:0] count = 0;
        
    always @(posedge CLOCK) begin
       count <= (count == m) ? 0 : count + 1;
       OUT_CLOCK <= (count == 0) ? ~OUT_CLOCK : OUT_CLOCK;
    end
endmodule
