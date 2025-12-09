`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/29 20:54:21
// Design Name: 
// Module Name: ajxd
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


module ajxd(
    input clk,
    input  [3:0] btn_in,
    output [3:0] btn_out,
    input en
    );
 
reg clk_20ms = 0;
reg [31:0] temp = 0;
always@(posedge clk)
begin
    if(en == 1)
    begin
        temp <= 0;
        clk_20ms <= 0;
    end
    else if(temp == 999999)
        begin
            temp <= 0;
            clk_20ms <= 1;
        end
        else if(temp < 999999)
            begin
                clk_20ms <= 0;
                temp <= temp+1;
            end
end    
 
reg [3:0] btn0;
reg [3:0] btn1;
reg [3:0] btn2;
initial
begin
btn0=0;
btn1=0;
btn2=0;
end
 
always@(posedge clk_20ms)
begin
btn0<=btn_in;
btn1<=btn0;
btn2<=btn1;
end
 
assign btn_out=((btn0&btn1)&(~btn2) | (btn0&btn1&btn2) | ((~btn0)&btn1&btn2));
 
endmodule