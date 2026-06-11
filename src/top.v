//==============================================================================
// 电子密码锁 - 修正版：状态机直接检测rx_done和换行符
//==============================================================================

module top #(
    parameter SYS_CLK = 50_000_000,
    parameter BAUD    = 9600
)(
    input        sys_clk,
    input        sys_rst_n,
    input        rx,
    output       tx,
    output       Led_n
);

    //==========================================================================
    // 复位同步
    //==========================================================================
    reg rst_d1, rst_d2;
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            rst_d1 <= 1;
            rst_d2 <= 1;
        end else begin
            rst_d1 <= 0;
            rst_d2 <= rst_d1;
        end
    end
    wire reset = rst_d2;

    //==========================================================================
    // 串口接收
    //==========================================================================
    wire [7:0] rx_data;
    wire       rx_done;

    uart_rx #(
        .CLK_FREQ(SYS_CLK),
        .UART_BPS(BAUD)
    ) uart_rx_inst (
        .rx_clk     (sys_clk),
        .rx_rst_n   (~reset),
        .rx_in_data (rx),
        .rx_done    (rx_done),
        .rx_data    (rx_data)
    );

    //==========================================================================
    // 串口发送
    //==========================================================================
    wire [7:0] tx_data;
    wire       tx_done;

    uart_tx #(
        .CLK_FREQ(SYS_CLK),
        .UART_BPS(BAUD)
    ) uart_tx_inst (
        .tx_clk        (sys_clk),
        .tx_rst_n      (~reset),
        .tx_in_data    (tx_data),
        .tx_enable     (~fifo_empty),
        .tx_out_data   (tx),
        .tx_data_ready (tx_done)
    );

    //==========================================================================
    // FIFO回显
    //==========================================================================
    wire [7:0] fifo_q;
    wire       fifo_empty;
    wire       fifo_full;

    fifo_sc fifo_inst (
        .Clk            (sys_clk),
        .Reset          (reset),
        .Data           (rx_data),
        .WrEn           (rx_done),
        .RdEn           (tx_done),
        .Q              (fifo_q),
        .Almost_Empty   (fifo_empty),
        .Full           (fifo_full),
        .Empty          ()
    );

    assign tx_data = fifo_q;

    //==========================================================================
    // 密码锁控制 - 单always块
    //==========================================================================
    localparam IDLE       = 3'd0;
    localparam SET_PWD    = 3'd1;
    localparam LOCKED     = 3'd2;
    localparam UNLOCK_PWD = 3'd3;
    localparam VERIFY     = 3'd4;
    localparam ALARM      = 3'd5;

    reg [2:0]  state;
    reg [23:0] stored_pwd;
    reg [23:0] input_pwd;
    reg [1:0]  pwd_cnt;
    reg [23:0] blink_cnt;
    reg        blink_led;
    reg        led_n_reg;
    
    reg [2:0]  cmd_cnt;
    reg [7:0]  cmd_buf [0:5];
    
    reg [7:0]  pwd_char0, pwd_char1, pwd_char2;
    
    assign Led_n = led_n_reg;

    // 换行符检测
    wire is_newline = (rx_data == 8'h0D) || (rx_data == 8'h0A);
    
    // lock命令检测
    wire is_lock = (cmd_cnt == 3'd4) && 
                   (cmd_buf[0] == "l") && (cmd_buf[1] == "o") &&
                   (cmd_buf[2] == "c") && (cmd_buf[3] == "k");
    
    // unlock命令检测
    wire is_unlock = (cmd_cnt == 3'd6) &&
                     (cmd_buf[0] == "u") && (cmd_buf[1] == "n") &&
                     (cmd_buf[2] == "l") && (cmd_buf[3] == "o") &&
                     (cmd_buf[4] == "c") && (cmd_buf[5] == "k");

    integer i;

    always @(posedge sys_clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            stored_pwd  <= 0;
            input_pwd   <= 0;
            pwd_cnt     <= 0;
            blink_cnt   <= 0;
            blink_led   <= 0;
            led_n_reg   <= 1;
            
            cmd_cnt     <= 0;
            for (i = 0; i < 6; i = i + 1) cmd_buf[i] <= 0;
            
            pwd_char0   <= 0;
            pwd_char1   <= 0;
            pwd_char2   <= 0;
            
        end else begin
            // 10Hz闪烁
            blink_cnt <= blink_cnt + 1;
            if (blink_cnt >= SYS_CLK / 10 - 1) begin
                blink_cnt <= 0;
                blink_led <= ~blink_led;
            end
            
            //==================================================================
            // 命令缓冲（所有状态都接收字符）
            //==================================================================
            if (rx_done && !is_newline && cmd_cnt < 3'd6) begin
                cmd_buf[cmd_cnt] <= rx_data;
                cmd_cnt <= cmd_cnt + 1;
            end
            
            //==================================================================
            // 主状态机
            //==================================================================
            case (state)
                //--------------------------------------------------------------
                // IDLE: 开锁，等待lock
                //--------------------------------------------------------------
                IDLE: begin
                    led_n_reg <= 1;     // LED灭
                    pwd_cnt   <= 0;
                    
                    if (rx_done && is_newline) begin
                        if (is_lock) begin
                            state   <= SET_PWD;
                            cmd_cnt <= 0;
                        end
                        else begin
                            cmd_cnt <= 0;  // 无效命令，清空
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // SET_PWD: 接收3位密码
                //--------------------------------------------------------------
                SET_PWD: begin
                    led_n_reg <= 0;     // LED亮
                    
                    if (rx_done && !is_newline) begin
                        case (pwd_cnt)
                            2'd0: pwd_char0 <= rx_data;
                            2'd1: pwd_char1 <= rx_data;
                            2'd2: pwd_char2 <= rx_data;
                        endcase
                        pwd_cnt <= pwd_cnt + 1;
                    end
                    
                    if (pwd_cnt >= 2'd2 && rx_done && !is_newline) begin
                        stored_pwd <= {pwd_char0, pwd_char1, rx_data};
                        state      <= LOCKED;
                        pwd_cnt    <= 0;
                        cmd_cnt    <= 0;  // 清空命令缓冲
                    end
                end
                
                //--------------------------------------------------------------
                // LOCKED: 已上锁，等待unlock
                //--------------------------------------------------------------
                LOCKED: begin
                    led_n_reg <= 0;     // LED亮
                    
                    if (rx_done && is_newline) begin
                        if (is_unlock) begin
                            state   <= UNLOCK_PWD;
                            cmd_cnt <= 0;
                            pwd_cnt <= 0;
                        end
                        else begin
                            cmd_cnt <= 0;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // UNLOCK_PWD: 输入开锁密码
                //--------------------------------------------------------------
                UNLOCK_PWD: begin
                    led_n_reg <= 0;
                    
                    if (rx_done && !is_newline) begin
                        case (pwd_cnt)
                            2'd0: pwd_char0 <= rx_data;
                            2'd1: pwd_char1 <= rx_data;
                            2'd2: pwd_char2 <= rx_data;
                        endcase
                        pwd_cnt <= pwd_cnt + 1;
                    end
                    
                    if (pwd_cnt >= 2'd2 && rx_done && !is_newline) begin
                        input_pwd <= {pwd_char0, pwd_char1, rx_data};
                        state     <= VERIFY;
                    end
                end
                
                //--------------------------------------------------------------
                // VERIFY: 验证密码
                //--------------------------------------------------------------
                VERIFY: begin
                    if (input_pwd == stored_pwd) begin
                        led_n_reg <= 1;     // 正确，开锁
                        state     <= IDLE;
                        cmd_cnt   <= 0;
                    end else begin
                        state <= ALARM;     // 错误，报警
                    end
                end
                
                //--------------------------------------------------------------
                // ALARM: 报警闪烁，等待unlock或lock
                //--------------------------------------------------------------
                ALARM: begin
                    led_n_reg <= blink_led ? 0 : 1;  // 10Hz闪烁
                    
                    if (rx_done && is_newline) begin
                        if (is_unlock) begin
                            state   <= UNLOCK_PWD;
                            cmd_cnt <= 0;
                            pwd_cnt <= 0;
                        end
                        else if (is_lock) begin
                            state   <= SET_PWD;
                            cmd_cnt <= 0;
                            pwd_cnt <= 0;
                        end
                        else begin
                            cmd_cnt <= 0;
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
