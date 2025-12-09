`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/02 15:33:49
// Design Name: 
// Module Name: fenpin
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


module fenpin(
    input clk,//50MHz
    input en,
    output reg clk_out//20MHz
    );
    
    // 50MHz to 20MHz: divide by 2.5
    // Using a counter to achieve 20MHz from 50MHz
    // Period ratio = 50/20 = 2.5
    // Use counter 0,1,2,3,4 (5 states) and toggle at different points
    
    reg [2:0] cnt;
    
    always @(posedge clk ) begin
        if (en) begin
            cnt <= 3'd0;
            clk_out <= 1'b0;
        end
        else begin
            if (cnt == 3'd4) begin
                cnt <= 3'd0;
            end
            else begin
                cnt <= cnt + 1'b1;
            end
            
            // Toggle clk_out to create 20MHz (period of 2.5 input clocks)
            if (cnt == 3'd0 || cnt == 3'd2) begin
                clk_out <= ~clk_out;
            end
        end
    end
    
endmodule
