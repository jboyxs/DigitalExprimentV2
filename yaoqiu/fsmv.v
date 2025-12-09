// 简易电梯两层FSM实现（使用外部按键消抖与显示模块）
// 约定：外部已提供消抖后的按键沿脉冲与显示驱动模块。
// - 按键：key*_pulse 为“上升沿”脉冲(1周期)，且已消抖
// - 显示：本模块输出状态码与楼层码，外部显示模块根据SW0显示“on/Off”与状态、楼层

module elevator_top (
    input  wire        clk,
    input  wire        rst_n,          // 低有效异步复位（板级）
    // 开关
    input  wire        SW0,            // 启动：上=启动有效；下=停机显示Off
    input  wire        SW11,           // 复位：下=强制回到1楼
    // 已消抖的按键上升沿脉冲输入（1个时钟周期）
    input  wire        key0_pulse,     // 1楼外向上（KEY0）
    input  wire        key1_pulse,     // 2楼外向下（KEY1）
    input  wire        key2_pulse,     // 电梯内1楼（KEY2）
    input  wire        key3_pulse,     // 电梯内2楼（KEY3）
    // 指示灯
    output reg         LED0,
    output reg         LED1,
    output reg         LED2,
    output reg         LED3,
    // 提供给外部数码管显示模块的编码信号
    output reg  [1:0]  disp_state_code,  // 0=IDLE, 1=UP, 2=DOWN
    output reg  [1:0]  disp_floor_code,  // 1=楼层1, 2=楼层2（编码用数值1或2）
    output reg         disp_show_on_pulse, // 当SW0由0->1时打一拍“on”
    output reg         disp_off_en        // 当SW0=0时显示“Off”
);

    //==============================
    // 参数与时间基准
    //==============================
    parameter integer CLK_FREQ_HZ = 50_000_000;        // 50MHz
    parameter integer SEC_TICKS   = CLK_FREQ_HZ;       // 1秒计数
    parameter integer RUN_SECONDS = 4;                 // 两层之间运行时间4秒
    parameter integer RUN_TICKS   = RUN_SECONDS * SEC_TICKS;

    //==============================
    // 状态定义
    //==============================
    typedef enum logic [2:0] {
        ST_IDLE_1   = 3'd0,
        ST_IDLE_2   = 3'd1,
        ST_UP       = 3'd2,
        ST_DOWN     = 3'd3,
        ST_FORCE_1  = 3'd4
    } state_t;

    state_t state, next_state;

    // 当前楼层：0=1楼，1=2楼
    reg [0:0] cur_floor;

    // 运行计时器
    reg [31:0] run_cnt;
    wire       run_done = (run_cnt >= RUN_TICKS);

    // 启动开关状态与沿检测
    reg  sw0_d1;
    wire start_en = (SW0 == 1'b1);
    wire sw0_rise = (start_en && !sw0_d1); // SW0 由0->1的沿（打一拍用于“on”显示）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sw0_d1 <= 1'b0;
        else        sw0_d1 <= start_en;
    end

    // 复位请求（向下为有效）
    wire force_reset_to_1 = (SW11 == 1'b0);

    // 请求脉冲（已消抖+沿）
    wire req_up_out_1_p    = key0_pulse; // KEY0
    wire req_down_out_2_p  = key1_pulse; // KEY1
    wire req_in_1_p        = key2_pulse; // KEY2
    wire req_in_2_p        = key3_pulse; // KEY3

    // 运行期返回队列标记
    reg pending_return_to_1;
    reg pending_return_to_2;

    //==============================
    // 时序：状态、计时、楼层、返回队列
    //==============================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= ST_IDLE_1;
            cur_floor           <= 1'b0; // 1楼
            run_cnt             <= 32'd0;
            pending_return_to_1 <= 1'b0;
            pending_return_to_2 <= 1'b0;
            disp_show_on_pulse  <= 1'b0;
            disp_off_en         <= 1'b0;
        end else begin
            state <= next_state;

            // “on/Off”显示控制信号
            disp_show_on_pulse <= sw0_rise;   // SW0由下拨到上：打一拍给显示模块
            disp_off_en        <= ~start_en;  // SW0=0：显示“Off”

            // 运行计数
            if (state == ST_UP || state == ST_DOWN || state == ST_FORCE_1) begin
                if (run_done) run_cnt <= 32'd0;
                else          run_cnt <= run_cnt + 1;
            end else begin
                run_cnt <= 32'd0;
            end

            // 楼层更新
            if (state == ST_UP   && run_done) cur_floor <= 1'b1; // 到2楼
            if (state == ST_DOWN && run_done) cur_floor <= 1'b0; // 到1楼
            if (state == ST_FORCE_1 && run_done) cur_floor <= 1'b0;

            // 运行中接受相反方向请求的排队逻辑（只在SW0=1时有效）
            if (start_en) begin
                if (state == ST_UP) begin
                    // 上行过程中，收到去1楼的反向请求 -> 到达2楼后下行
                    if (req_in_1_p || req_up_out_1_p) pending_return_to_1 <= 1'b1;
                end else if (state == ST_DOWN) begin
                    // 下行过程中，收到去2楼的反向请求 -> 到达1楼后上行
                    if (req_in_2_p || req_down_out_2_p) pending_return_to_2 <= 1'b1;
                end
            end

            // 到达楼层后，在随后的转移中会使用pending_*决定是否自动返回；
            // 当强制复位运行完成，清空队列
            if (state == ST_FORCE_1 && run_done) begin
                pending_return_to_1 <= 1'b0;
                pending_return_to_2 <= 1'b0;
            end
        end
    end

    //==============================
    // 组合：状态转移
    //==============================
    always @* begin
        next_state = state;

        // 强制复位优先
        if (force_reset_to_1) begin
            next_state = (cur_floor == 1'b0) ? ST_IDLE_1 : ST_FORCE_1;
        end else if (!start_en) begin
            // 启动关闭：保持待机（按当前楼层）
            next_state = (cur_floor == 1'b0) ? ST_IDLE_1 : ST_IDLE_2;
        end else begin
            case (state)
                ST_IDLE_1: begin
                    // 1楼待机时，仅KEY1或KEY3触发上行
                    if (req_down_out_2_p || req_in_2_p) next_state = ST_UP;
                    else                                next_state = ST_IDLE_1;
                end
                ST_IDLE_2: begin
                    // 2楼待机时，仅KEY0或KEY2触发下行
                    if (req_up_out_1_p || req_in_1_p)   next_state = ST_DOWN;
                    else                                next_state = ST_IDLE_2;
                end
                ST_UP: begin
                    if (run_done) begin
                        if (pending_return_to_1) next_state = ST_DOWN; // 自动返回1楼
                        else                     next_state = ST_IDLE_2;
                    end
                end
                ST_DOWN: begin
                    if (run_done) begin
                        if (pending_return_to_2) next_state = ST_UP;   // 自动返回2楼
                        else                     next_state = ST_IDLE_1;
                    end
                end
                ST_FORCE_1: begin
                    if (run_done) next_state = ST_IDLE_1;
                end
                default: next_state = ST_IDLE_1;
            endcase
        end
    end

    //==============================
    // LED控制（严格按验收）
    //==============================
    // 规则总结：
    // - 1楼时按KEY0或KEY2：不亮（且不触发运动）
    // - 2楼时按KEY1或KEY3：不亮（且不触发运动）
    // - 有效请求触发对应LED点亮，并在目标楼层到达时熄灭
    // - 运行中按反向请求，完成当前目标后自动返回，再熄灭对应LED
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            LED0 <= 1'b0; LED1 <= 1'b0; LED2 <= 1'b0; LED3 <= 1'b0;
        end else begin
            if (!start_en || force_reset_to_1) begin
                // 启动关闭或强复位：所有指示灯灭
                LED0 <= 1'b0; LED1 <= 1'b0; LED2 <= 1'b0; LED3 <= 1'b0;
            end else begin
                // 点亮：仅在合法楼层与合法请求时锁存
                // 1楼待机 -> 上行请求：KEY1或KEY3
                if (state == ST_IDLE_1) begin
                    if (req_in_2_p)     LED3 <= 1'b1; // 在1楼按2楼键
                    if (req_down_out_2_p) LED1 <= 1'b1; // 在1楼收到2楼外向下请求
                    // 禁止：KEY0/KEY2在1楼不亮
                end
                // 2楼待机 -> 下行请求：KEY0或KEY2
                if (state == ST_IDLE_2) begin
                    if (req_in_1_p)     LED2 <= 1'b1; // 在2楼按1楼键
                    if (req_up_out_1_p) LED0 <= 1'b1; // 在2楼收到1楼外向上请求
                    // 禁止：KEY1/KEY3在2楼不亮
                end

                // 运行中点亮反向排队对应LED（满足验收“立刻按相反方向键，先到达当前再返回”）
                if (state == ST_UP) begin
                    if (req_in_1_p)     LED2 <= 1'b1; // 运行中按1楼键，待返回到1楼后灭
                    if (req_up_out_1_p) LED0 <= 1'b1; // 运行中收到1楼外向上请求
                end
                if (state == ST_DOWN) begin
                    if (req_in_2_p)     LED3 <= 1'b1; // 运行中按2楼键，待返回到2楼后灭
                    if (req_down_out_2_p) LED1 <= 1'b1; // 运行中收到2楼外向下请求
                end

                // 到达目标楼层后熄灭对应LED
                if (state == ST_UP && run_done) begin
                    // 完成上行到2楼：熄灭与到2楼目标相关的灯
                    LED1 <= 1'b0; // KEY1请求完成
                    LED3 <= 1'b0; // KEY3请求完成
                    // 若需返回1楼，LED0/LED2保持，待下行完成后灭
                end
                if (state == ST_DOWN && run_done) begin
                    // 完成下行到1楼：熄灭与到1楼目标相关的灯
                    LED0 <= 1'b0; // KEY0请求完成
                    LED2 <= 1'b0; // KEY2请求完成
                    // 若需返回2楼，LED1/LED3保持，待上行完成后灭
                end
            end
        end
    end

    //==============================
    // 显示输出编码（供外部显示模块使用）
    //==============================
    // disp_state_code: 0=IDLE, 1=UP, 2=DOWN
    // disp_floor_code: 1=楼层1, 2=楼层2
    always @(*) begin
        // 楼层
        disp_floor_code = (cur_floor == 1'b0) ? 2'd1 : 2'd2;

        // 启动关闭时，交由显示模块处理“Off/on”，此处仍提供状态
        case (state)
            ST_IDLE_1, ST_IDLE_2: disp_state_code = 2'd0;
            ST_UP:                 disp_state_code = 2'd1;
            ST_DOWN:               disp_state_code = 2'd2;
            ST_FORCE_1:            disp_state_code = 2'd2; // 视为向下
            default:               disp_state_code = 2'd0;
        endcase
    end

endmodule