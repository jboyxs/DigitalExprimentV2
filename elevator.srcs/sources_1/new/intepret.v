`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/01 22:49:07
// Design Name: 
// Module Name: intepret
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


module intepret(
    input fx,
    input [1:0] sx,
    input [1:0] sigma,
    input [3:0] unit,
    input en,
    input clk,//50MHz
    output reg [7:0] data_segfx,
    output reg [7:0] data_segsx,
    output reg [7:0] data_segtime0,
    output reg [7:0] data_segtime1


    );
    // 七段数码管译码
    reg [31:0] cnt;//用于计数
    always @(posedge clk) begin
        if(en) begin
            cnt<=0;
            data_segfx <= 8'b10001110; //F
            data_segsx <= 8'b10001110; //F
            data_segtime0 <= 8'b11111100; //O
            data_segtime1 <= 8'b00000000; 
        end 
        else begin
            if(cnt<100_000_000-1) begin
                cnt<=cnt+1;
            data_segfx <= 8'b11101100; 
            data_segsx <= 8'b11111100; 
            data_segtime0 <= 8'b00000000; 
            data_segtime1 <= 8'b00000000; //

            end
            else begin

            
//先显示一秒的ON，之后再正常显示
        case(fx)
            1'b0: data_segfx <= 8'b01100000; // 显示 "1"
            1'b1: data_segfx <= 8'b11011010; // 显示 "2"
            default: data_segfx <= 8'b00000000; // 全灭
        endcase
        case(sx)
            2'b00: data_segsx <= 8'b00000010; // 
            2'b01: data_segsx <= 8'b10000000; //
            2'b10: data_segsx <= 8'b00010000; // 
            default: data_segsx <= 8'b00000000; // 全灭
        endcase
        case(sigma)
        2'b00: data_segtime1 <= 8'b11111101; // 显示 "0"
        2'b01: data_segtime1 <= 8'b01100001; //显示 "1"
        2'b10: data_segtime1 <= 8'b11011011; //显示 "2"
        2'b11: data_segtime1 <= 8'b11110011; //显示 "3"
        default: data_segtime1 <= 8'b00000001; // 全灭(只亮小数点)
        endcase
        case(unit)
            4'd0: data_segtime0 <= 8'b11111100; // 显示 "0"
            4'd1: data_segtime0 <= 8'b01100000;// 显示 "1"
            4'd2: data_segtime0 <= 8'b11011010; // 显示 "2"
            4'd3: data_segtime0 <= 8'b11110010; // 显示 "3"
            4'd4: data_segtime0 <= 8'b01100110; // 显示 "4"
            4'd5: data_segtime0 <= 8'b10110110;// 显示 "5"
            4'd6: data_segtime0 <= 8'b00111110; // 显示 "6"
            4'd7: data_segtime0 <= 8'b11100000; // 显示 "7"
            4'd8: data_segtime0 <= 8'b11111110; // 显示 "8"
            4'd9: data_segtime0 <= 8'b11100110;// 显示 "9"
            default: data_segtime0 <= 8'b11111100; // 显示 "0"
        endcase
        
        end
    end
        end
endmodule
