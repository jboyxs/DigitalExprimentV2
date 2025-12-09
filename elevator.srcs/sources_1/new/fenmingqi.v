`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/02 15:33:26
// Design Name: 
// Module Name: fenmingqi
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 蜂鸣器驱动：电梯每到达一个新楼层（sx 由运行态变为空闲态）时，
//              发出间隔 0.5 秒的三声清晰“嘀”声。
// 
//////////////////////////////////////////////////////////////////////////////////

module fenmingqi(
    input        clk,          // 同步时钟信号 50MHz
    input  [1:0] sx,           // fsm 状态机输出：00 空闲，01 上行，10 下行
    output reg   buzzer        // 蜂鸣器输出
);

// ---------------- 参数配置 ----------------
localparam CLK_FREQ      = 50_000_000;          // 时钟频率 50MHz
localparam BEEP_FREQ     = 2000;                // 蜂鸣器方波频率，约 2kHz
localparam HALF_PERIOD_T = CLK_FREQ / (2*BEEP_FREQ); // 方波高/低电平计数

localparam HALF_SEC_CNT  = CLK_FREQ / 2;        // 0.5 秒：25_000_000 周期
localparam BEEP_NUM      = 3;                   // 发声次数 3 次

// 状态编码：用于控制整个“滴滴滴”序列
localparam IDLE       = 2'd0;
localparam BEEP_ON    = 2'd1;
localparam BEEP_OFF   = 2'd2;

reg [1:0] sx_d;              // 上一拍 sx，用于边沿/状态变化检测
reg [1:0] seq_state = IDLE;  // 序列控制状态机
reg [1:0] beep_cnt  = 0;     // 已经发出的滴声计数 (0~BEEP_NUM)
reg [31:0] time_cnt = 0;     // 0.5 秒计数
reg [15:0] wave_cnt = 0;     // 生成 2kHz 方波的分频计数
reg        wave      = 0;    // 2kHz 方波信号

// ---------------- 2kHz 方波产生 ----------------
always @(posedge clk) begin
    if (wave_cnt >= HALF_PERIOD_T - 1) begin
        wave_cnt <= 0;
        wave     <= ~wave;
    end else begin
        wave_cnt <= wave_cnt + 1;
    end
end

// ---------------- 主序列控制：三声，每声 0.5s ----------------
always @(posedge clk) begin
    // 记录上一拍 sx
    sx_d <= sx;

    case (seq_state)
        IDLE: begin
            buzzer   <= 1'b0;
            time_cnt <= 32'd0;
            beep_cnt <= 2'd0;

            // 触发条件修改：
            // 原来：从空闲(00) -> 上行(01) 或 下行(10) 触发
            // 现在：从运行(01/10) -> 空闲(00) 触发，表示到达一个新楼层
            if ((sx_d == 2'b01 || sx_d == 2'b10) && sx == 2'b00) begin
                seq_state <= BEEP_ON;
                time_cnt  <= 32'd0;
                beep_cnt  <= 2'd0;
            end
        end

        // 蜂鸣器响 0.5s，内部为 2kHz 波形
        BEEP_ON: begin
            buzzer   <= wave;                 // 输出高频方波
            if (time_cnt >= HALF_SEC_CNT-1) begin
                time_cnt <= 32'd0;
                beep_cnt <= beep_cnt + 1'b1;  // 完成一声
                if (beep_cnt == BEEP_NUM-1) begin
                    // 已经发够 3 声，回到空闲
                    seq_state <= IDLE;
                    buzzer    <= 1'b0;
                end else begin
                    // 进入静音间隔 0.5s
                    seq_state <= BEEP_OFF;
                end
            end else begin
                time_cnt <= time_cnt + 1'b1;
            end
        end

        // 静音 0.5s
        BEEP_OFF: begin
            buzzer <= 1'b0;
            if (time_cnt >= HALF_SEC_CNT-1) begin
                time_cnt  <= 32'd0;
                seq_state <= BEEP_ON;         // 再响下一声
            end else begin
                time_cnt <= time_cnt + 1'b1;
            end
        end

        default: begin
            seq_state <= IDLE;
            buzzer    <= 1'b0;
        end
    endcase
end

endmodule