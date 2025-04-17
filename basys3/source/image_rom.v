`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.03.2025 22:18:51
// Design Name: 
// Module Name: image_rom
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


module image_rom #(
    parameter MEMFILE = "menu.mem"  // default memory file; override for other levels
)(
    input  wire         clk,
    input  wire [12:0]  addr,    // 13-bit address for 96x64 = 6144 pixels
    output reg  [15:0]  data
);
    // Declare ROM with 6144 words of 16 bits
    reg [15:0] rom [0:6143];

    // Initialize ROM with the given .mem file (make sure the file is in your project)
    initial begin
        $readmemh(MEMFILE, rom);
    end

    // Synchronous read: output pixel data on rising clock edge
    always @(posedge clk) begin
        data <= rom[addr];
    end
endmodule

