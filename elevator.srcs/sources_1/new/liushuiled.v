`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/01 23:34:16
// Design Name: 
// Module Name: liushuiled
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


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: liushuiled
// Description:
// 根据 fsm 输出的 sx 状态，在运行过程中驱动 5 个流水灯：
//  - sx = 2'b00：电梯空闲，5 灯全灭
//  - sx = 2'b01：电梯上行，LED 从左到右每 0.8s 依次点亮
//  - sx = 2'b10：电梯下行，LED 从右到左每 0.8s 依次点亮
//////////////////////////////////////////////////////////////////////////////////

module liushuiled(
    input  wire        clk,   // 同步时钟 50MHz
    input  wire [1:0]  sx,    // fsm 状态：00 空闲，01 上行，10 下行
    output reg  [4:0]  led    // 5 个流水灯
    );
    // 0.8s 计数常数：50MHz * 0.8s = 40_000_000
    localparam CNT_WIDTH = 26;            // 2^26 ≈ 67M > 40M
    localparam CNT_MAX   = 26'd40_000_000 - 1;

    reg [CNT_WIDTH-1:0] cnt;
    reg [2:0]           pos;              // 当前点亮的位置 0..4

    always @(posedge clk) begin
        case (sx)
            2'b01: begin
                // 上行：从左到右流动
                if (cnt >= CNT_MAX) begin
                    cnt <= 0;
                    // 位置 0->4 循环
                    if (pos == 3'd4)
                        pos <= 3'd0;
                    else
                        pos <= pos + 1'b1;
                end
                else begin
                    cnt <= cnt + 1'b1;
                end

                // 根据 pos 点亮对应的一个 LED，其余为 0
                case (pos)
                    3'd0: led <= 5'b10000; // 最左边亮
                    3'd1: led <= 5'b01000;
                    3'd2: led <= 5'b00100;
                    3'd3: led <= 5'b00010;
                    3'd4: led <= 5'b00001; // 最右边亮
                    default: led <= 5'b00000;
                endcase
            end

            2'b10: begin
                // 下行：从右到左流动
                if (cnt >= CNT_MAX) begin
                    cnt <= 0;
                    // 位置 0->4 循环（这里用同一个 pos，只是映射到相反方向）
                    if (pos == 3'd4)
                        pos <= 3'd0;
                    else
                        pos <= pos + 1'b1;
                end
                else begin
                    cnt <= cnt + 1'b1;
                end

                // pos 仍然 0..4，但映射顺序反过来
                case (pos)
                    3'd0: led <= 5'b00001; // 最右边亮
                    3'd1: led <= 5'b00010;
                    3'd2: led <= 5'b00100;
                    3'd3: led <= 5'b01000;
                    3'd4: led <= 5'b10000; // 最左边亮
                    default: led <= 5'b00000;
                endcase
            end

            default: begin
                // 空闲或其它状态：计数器清零，灯灭
                cnt <= 0;
                pos <= 0;
                led <= 5'b00000;
            end
        endcase
    end

endmodule