`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: fsm
// Description: 电梯状态机完整版
// Features: 
// 1. 智能归位 (HOMING)
// 2. 请求记忆与LED控制 (Request Memory)
// 3. 运行时间显示 (Time Display)
//////////////////////////////////////////////////////////////////////////////////

module fsm(
    input [3:0] xdkey,
    input clk,
    input rst,      
    input en,
    output reg [3:0] led, // led[3]:去2楼请求, led[2]:去1楼请求
    output reg fx,        // 0:1楼, 1:2楼
    output reg [1:0] sx,  // 输出状态指示00:空闲，01:上行 10:下行
    // 运行时间显示 0.0 - 3.9s
    output reg [1:0] sigma, // 个位
    output reg [3:0] unit    // 个分位
    );

    parameter ST_IDLE_1   = 3'd0;// 空闲在1楼
    parameter ST_IDLE_2   = 3'd1;// 空闲在2楼
    parameter ST_UP       = 3'd2; // 上行
    parameter ST_DOWN     = 3'd3; // 下行
    parameter ST_FORCE_1  = 3'd4; // 强制回1楼
    parameter CntWidth    = 32;
    parameter CntMax      = 200000000;//50M 4s计数值

    reg [2:0] state, next_state;
    reg timeend;               // 运行时间到达标志

    // 在上行途中是否记下了“从2楼回1楼”的自动回程请求
    // 场景：1楼上行时按 KEY2 或 KEY0，先到2楼，再自动回1楼
    reg need_return_to_1;

    // 在下行途中是否记下了“从1楼回2楼”的自动回程请求
    // 场景：2楼下行时按 KEY3 或 KEY1，先到1楼，再自动回2楼
    reg need_return_to_2;

    // 状态寄存器
    always @(posedge clk) begin
        if (en)
            state <= ST_IDLE_1;
        else
            state <= next_state;
    end

    // 状态转移逻辑
    always @(posedge clk) begin
        case (state)
            // 在1楼空闲：
            // 1）如果之前下行途中记录过 need_return_to_2，则自动上行回2楼
            // 2）否则，只在有人按 KEY1/KEY3 时上行到2楼
            ST_IDLE_1: begin
                if (need_return_to_2) begin
                    next_state = ST_UP;            // 自动回2楼
                end
                else begin
                    case ({xdkey[1], xdkey[3]})
                        2'b01: next_state = ST_UP;
                        2'b10: next_state = ST_UP;
                        2'b11: next_state = ST_UP;
                        default: next_state = ST_IDLE_1;
                    endcase
                end
            end

            // 在2楼空闲：
            // 1）如果之前上行途中记录过 need_return_to_1，则自动下行回1楼
            // 2）否则，保持原逻辑：有人在2楼按 KEY0/KEY2 或 rst 才下行
            ST_IDLE_2: begin
                if (need_return_to_1) begin
                    next_state = ST_DOWN;          // 自动回1楼
                end
                else begin
                    case ({xdkey[0], xdkey[2], rst})
                        3'b000: next_state = ST_IDLE_2;
                        3'b001: next_state = ST_FORCE_1; // 复位，强制回1楼
                        3'b010: next_state = ST_DOWN;
                        3'b100: next_state = ST_DOWN;
                        3'b011: next_state = ST_FORCE_1;
                        3'b101: next_state = ST_FORCE_1; // 复位
                        3'b110: next_state = ST_DOWN;
                        3'b111: next_state = ST_FORCE_1; // 复位
                        default: next_state = ST_DOWN;
                    endcase
                end
            end

            // 上行过程
            ST_UP: begin
                case ({rst, timeend})
                    2'b00: next_state = ST_UP;        // 正常计时中
                    2'b01: next_state = ST_IDLE_2;    // 到2楼
                    2'b10: next_state = ST_FORCE_1;   // 复位，强制回1楼
                    2'b11: next_state = ST_IDLE_2;    // 计时到且复位，仍到2楼
                endcase
            end

            // 下行过程
            ST_DOWN: begin
                case ({timeend,rst})
                    2'b00: next_state = ST_DOWN;
                    2'b01: next_state = ST_FORCE_1; // 复位，强制回1楼
                    2'b10: next_state = ST_IDLE_1;   // 到1楼
                    2'b11: next_state = ST_FORCE_1; // 复位，
                    default: next_state = ST_IDLE_1;  // 到1楼
                endcase
            end

            // 强制回1楼
            ST_FORCE_1: begin
                case (timeend)
                    1'b0: next_state = ST_FORCE_1;
                    default: next_state = ST_IDLE_1;
                endcase
            end

            default: next_state = ST_IDLE_1;
        endcase
    end 

    // 计数器：用于模拟运行时间
    // reg [CntWidth-1:0] cntmark;
    reg [CntWidth-1:0] cnt;
    // reg [CntWidth-1:0] cntmaxforce;
    reg homeback;
    always @(posedge clk ) begin
        if(en) begin
            cnt <= CntMax-1;
            timeend <=0;
            homeback<=0;
        end
        else begin
            case(state)
                ST_UP: begin
                    if(cnt > 0) begin
                        cnt <= cnt - 1;
                        timeend <=0;
                        // cntmark<=cnt;
                    end
                    else begin
                        cnt <= cnt;
                        timeend <=1;
                    end
                end
                ST_DOWN: begin
                    if(cnt < CntMax-1) begin
                        cnt <= cnt +1;
                        timeend <=0;
                        // cntmark<=cnt;
                    end
                    else begin
                        cnt <= cnt;
                        timeend <=1;
                    end
                end

                ST_FORCE_1:begin//这个计数逻辑要改，从倒计改成正计
                    if(cnt<CntMax-1) begin
                        cnt<=cnt+1;
                        timeend <=0;
                        homeback<=1;
                    end
                    else begin
                        cnt<=cnt;
                        timeend <=1;
                        homeback<=0;
                    end
               end
               ST_IDLE_2:begin
                    cnt <= 0;
                    timeend <=0;
               end

                default: begin
                    cnt <= CntMax-1;
                    timeend <=0;
                end

            endcase
        end
end
//定时器2
reg [CntWidth-1:0] cntv;
always @(posedge clk) begin
if(!homeback)begin
    cntv<=0;
end
else begin
    cntv<=cntv+1;
end
    
end
    // 输出逻辑（位置 / 状态 / LED）
    always @(posedge clk) begin
        if (en) begin
            fx   <= 0;
            sx   <= 2'b00;
            led  <= 0;
            need_return_to_1 <= 1'b0;
            need_return_to_2 <= 1'b0;
        end
        else begin
            case (state)
                // 1楼空闲：
                // 如果是普通回到1楼（没有 need_return_to_2），清所有灯和标志；
                // 如果是“自动回2楼”的中途落点，则先到 ST_UP，再在到2楼时清灯。
                ST_IDLE_1: begin
                    fx   <= 0;
                    sx   <= 2'b00;
                    if (need_return_to_2) begin
                        // 处于“还要自动回2楼”的中间点，不立即清 led 和 need_return_to_2，
                        // 在上行结束到2楼空闲时清。
                        led[0] <= 0;
                        led[2] <= 0;
                        led[1] <= led[1];
                        led[3] <= led[3];
                    end
                    else begin
                        led <= 0;              // 正常回到1楼：清除所有请求
                        need_return_to_1 <= 1'b0;
                        need_return_to_2 <= 1'b0;
                    end
                end

                // 2楼空闲：
                // 如果是普通回到2楼（没有 need_return_to_1），保持或清由你自己控制；
                // 如果是“自动回1楼”的中途落点，则先到 ST_DOWN，再在到1楼时清灯。
                ST_IDLE_2: begin
                    fx   <= 1;
                    sx   <= 2'b00;
                    if (need_return_to_1) begin
                        // 仍然处在“需要自动回1楼”的中途，不清 led
                        led[1] <= 0;
                        led[3] <= 0;
                        led[0] <= led[0];
                        led[2] <= led[2];
                    end
                    else begin
                        // 普通到2楼空闲时可以选择保持或清零
                        led <= 0;
                        need_return_to_1 <= 1'b0;
                        need_return_to_2 <= 1'b0;
                    end
                end

                // 上行：从1楼到2楼
                ST_UP: begin
                    // fx 显示当前位置
                    if (cnt < CntMax*1/4)
                        fx <= 1;
                    else
                        fx <= 0;

                    sx <= 2'b01;    // 上行动作指示

                    // 记录去2楼请求（1楼外呼或内呼）
                    case ({xdkey[1], xdkey[3]})
                        2'b01: led[3] <= 1;   // 记录：1楼上行请求（例如外呼）
                        2'b10: led[1] <= 1;   // 记录：内部去2楼请求
                        2'b11: begin
                            led[3] <= 1;
                            led[1] <= 1;
                        end
                        default: led <= led;
                    endcase

                    // 上行途中：如果有人按 KEY2 / KEY0（到1楼）
                    // 则到2楼后自动回1楼
                    if (xdkey[2])
                        led[2] <= 1'b1;   // 2→1 请求
                    if (xdkey[0])
                        led[0] <= 1'b1;   // 2→1 请求

                    if (xdkey[2] || xdkey[0])
                        need_return_to_1 <= 1'b1;

                    // 当上行结束到达2楼空闲时（下一拍 state 会变 ST_IDLE_2），
                    // 如果这是“自动回2楼”的二段（need_return_to_2=1），
                    // 则在后续 ST_IDLE_2 中清灯（见 ST_IDLE_2 分支）。
                    if (timeend && need_return_to_2) begin
                        // 到达2楼，自动回2楼过程结束：清对应上行请求灯
                        led[3] <= 1'b0;
                        led[1] <= 1'b0;
                        need_return_to_2 <= 1'b0;
                    end
                end

                // 下行：从2楼到1楼
                ST_DOWN: begin
                    if (cnt > CntMax*3/4)
                        fx <= 0;
                    else
                        fx <= 1;

                    sx <= 2'b10;    // 下行动作指示

                    // 下行时记录去1楼 / 去2楼请求（保留你原先的逻辑）
                    case ({xdkey[0], xdkey[2]})
                        2'b01: led[2] <= 1;   // 记录去1楼请求
                        2'b10: led[0] <= 1;   // 记录去2楼请求（如果你有这个需求）
                        2'b11: begin
                            led[2] <= 1;
                            led[0] <= 1;
                        end
                        default: led <= led;
                    endcase

                    // 下行途中：如果有人按 KEY3 / KEY1（到2楼）
                    // 则到1楼后自动再上行回2楼
                    if (xdkey[3])
                        led[3] <= 1'b1;   // 1→2 请求（例如1楼外呼上行）
                    if (xdkey[1])
                        led[1] <= 1'b1;   // 1→2 请求（内部去2楼）

                    if (xdkey[3] || xdkey[1])
                        need_return_to_2 <= 1'b1;

                    // 当下行结束到达1楼空闲时（下一拍 state 会变 ST_IDLE_1），
                    // 如果这是“自动回1楼”的二段（need_return_to_1=1），
                    // 则在后续 ST_IDLE_1 中清灯（见 ST_IDLE_1 分支）。
                    if (timeend && need_return_to_1) begin
                        // 到达1楼，自动回1楼过程结束：清对应下行请求灯
                        led[2] <= 1'b0;
                        led[0] <= 1'b0;
                        need_return_to_1 <= 1'b0;
                    end
                end

                // 强制回1楼
                ST_FORCE_1: begin
                    if (cnt > CntMax*3/4)
                        fx <= 0;
                    else
                        fx <= 1;

                    sx  <= 2'b10;
                    led <= 4'b1111;   // 全亮，表示强制动作
                    // 强制回1楼结束后，在 ST_IDLE_1 中统一清空标志
                    need_return_to_1 <= 1'b0;
                    need_return_to_2 <= 1'b0;
                end

                default: begin
                    fx   <= 0;
                    sx   <= 2'b00;
                    led  <= 0;
                    need_return_to_1 <= 1'b0;
                    need_return_to_2 <= 1'b0;
                end
            endcase
        end
    end

    // ...existing code...
    
        // 计时显示：sigma(秒) 和 unit(十分位)
        // 显示“剩余时间”，3.9 ~ 0.0s，cnt 从 CntMax-1 递减到 0
        reg [CntWidth-1:0] seg_len;     // 每 0.1s 对应的计数长度
        reg [CntWidth-1:0] remain;      // 剩余计数
        reg [5:0]          idx;         // 0..39 -> 3.9..0.0
    
        always @(posedge clk) begin
            if (en) begin
                // 复位时显示 3.9
                sigma <= 2'd3;
                unit  <= 4'd9;
            end
            else begin
                if (state == ST_IDLE_1 || state == ST_IDLE_2) begin
                    // 空闲时显示 0.0
                    sigma <= 0;
                    unit  <= 0;
                end
                else begin
                    case(state)
                        ST_UP: begin
                        seg_len = CntMax / 40;
                        remain  = cnt;
                        idx = remain / seg_len;
                        sigma <= idx / 10;
                        unit  <= idx % 10;      
                        end
                        ST_DOWN: begin
                        seg_len = CntMax / 40;
                        remain  = cnt;
                        idx = remain / seg_len;
                        sigma <= (40-idx) / 10;
                        unit  <= (40-idx) % 10;    
                        end
                        ST_FORCE_1: begin//正计时显示已经上升了多长时间
                        seg_len = CntMax / 40;
                        remain  = cntv;
                        idx = remain / seg_len;
                        sigma <= idx / 10;
                        unit  <= idx % 10;   
                        end

            default:begin 

                    // 把 4 秒分成 40 份，每份 0.1s
                    // seg_len = CntMax / 40（定值，可综合成常量）
                    seg_len = CntMax / 40;
    
                    // 剩余计数：cnt 从 CntMax-1 递减到 0
                    remain  = cnt;
    
                    // 计算当前是第几个 0.1s 段（0..39）
                    // 为了倒计时，从 3.9 开始，所以：
                    // idx = remain / seg_len  仍是 0..39，
                    // 直接用 idx 表示“距离结束还有 idx 个 0.1s”
                    idx = remain / seg_len;   // 0..39，对应 0.0~3.9
    
                    // 3.9 -> 0.0：idx=39 -> 0
                    // sigma = idx / 10, unit = idx % 10
                    sigma <= idx / 10;        // 3..0
                    unit  <= idx % 10;        // 9..0
            end
                    endcase
                end
            end
        end
    
    // ...existing code...

endmodule