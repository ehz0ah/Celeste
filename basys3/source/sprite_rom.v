`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.03.2025 00:30:48
// Design Name: 
// Module Name: sprite_rom
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


module sprite_rom #(
    parameter MEMFILE = "chibi.mem"  // File for the 7x7 sprite
)(
    input  wire         clk,
    input  wire [5:0]   addr,   // 6-bit address to cover 7x7 = 49 pixels
    output reg  [15:0]  data
);
    // Declare a ROM with 49 16-bit words
    reg [15:0] rom [0:48];

    initial begin
        $readmemh(MEMFILE, rom);
    end

    always @(posedge clk) begin
        data <= rom[addr];
    end
endmodule


