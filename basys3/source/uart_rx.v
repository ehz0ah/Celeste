`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.04.2025 00:36:47
// Design Name: 
// Module Name: uart_rx
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


module uart_rx (
    input clk,            // 100 MHz clock
    input rx,             // UART RX line
    output reg [7:0] data,
    output reg valid
);

    localparam CLK_PER_BIT = 10417;   // 100 MHz / 9600 baud ? 10417
    localparam IDLE  = 0,
               START = 1,
               READ  = 2,
               STOP  = 3,
               DONE  = 4;

    reg [2:0] state = IDLE;
    reg [13:0] clk_count = 0;      // Enough bits to count to 10417
    reg [2:0] bit_index = 0;
    reg [7:0] rx_shift = 0;
    reg rx_sync = 1;

    always @(posedge clk) begin
        rx_sync <= rx;  // Simple 1-bit synchronizer

        case (state)
            IDLE: begin
                valid <= 0;
                clk_count <= 0;
                bit_index <= 0;

                if (rx_sync == 0)  // Start bit detected
                    state <= START;
            end

            START: begin
                if (clk_count == (CLK_PER_BIT/2)) begin
                    if (rx_sync == 0) begin
                        clk_count <= 0;
                        state <= READ;
                    end else
                        state <= IDLE;  // False start
                end else
                    clk_count <= clk_count + 1;
            end

            READ: begin
                if (clk_count == CLK_PER_BIT - 1) begin
                    clk_count <= 0;
                    rx_shift[bit_index] <= rx_sync;
                    bit_index <= bit_index + 1;
                    if (bit_index == 7)
                        state <= STOP;
                end else
                    clk_count <= clk_count + 1;
            end

            STOP: begin
                if (clk_count == CLK_PER_BIT - 1) begin
                    clk_count <= 0;
                    state <= DONE;
                end else
                    clk_count <= clk_count + 1;
            end

            DONE: begin
                data <= rx_shift;
                valid <= 1;
                state <= IDLE;
            end
        endcase
    end
endmodule
