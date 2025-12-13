`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/02 11:40:44
// Design Name: 
// Module Name: top
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


module top(
    input clk,//50MHz
    input rstv,
    input env,
    input [3:0] key,
    output wire  [3:0] state_led ,
    output wire buzzer,
    output wire [4:0] liushui_led,
    output [3:0] row,
    output [7:0] data_seg,
    output [5:0] data_dig

    );
    wire en=~env;
    wire rst=~rstv;
    assign row = 4'b1110; // 扫描第一行
    wire [3:0] key_xd;
    wire clk_20MHz;
    fenpin u0(
        .clk(clk),
        .en(en),
        .clk_out(clk_20MHz)
    );
    ajxd u1(
        .clk(clk_20MHz),
        .btn_in(key),
        .btn_out(key_xd),
        .en(en)
    );
    wire key0, key1, key2, key3;
    assign key0=~(key_xd[0]|row[0]);//明天试一试把这个给这个改掉看一看
    assign key1=~(key_xd[1]|row[0]);
    assign key2=~(key_xd[2]|row[0]);
    assign key3=~(key_xd[3]|row[0]);
    wire fx;
    wire [1:0] sx;
    wire [1:0] sigma;
    wire [3:0] unit;
    fsm u2(
        .xdkey({key3,key2,key1,key0}),
        .clk(clk),
        .rst(rst),
        .en(en),
        .led(state_led), 
        .fx(fx),
        .sx(sx),
        .sigma(sigma),
        .unit(unit)
    );
    wire [8:0] data_segfx;
    wire [8:0] data_segsx;
    wire [8:0] data_segtime0;
    wire [8:0] data_segtime1;

    intepret u3(
        .fx(fx),
        .sx(sx),
        .en(en),
        .clk(clk),
        .sigma(sigma),
        .unit(unit),
        .data_segfx(data_segfx),
        .data_segsx(data_segsx),
        .data_segtime0(data_segtime0),
        .data_segtime1(data_segtime1)
    );

    liushuiled u4(
        .clk(clk),
        .sx(sx),
        .led(liushui_led)
    );

    fenmingqi u5(.clk(clk),
        .sx(sx),
        .buzzer(buzzer)
    );


    seg_scan u6(
        .clk(clk),
        .data_seg0(data_segfx), // 最右位
        .data_seg1(data_segsx),
        .data_seg2(data_segtime0),// 扩展显示
        .data_seg3(data_segtime1),// 扩展显示(最左位)
        .data_seg(data_seg),
        .data_dig(data_dig)
    );

endmodule
