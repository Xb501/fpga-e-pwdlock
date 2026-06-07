//==============================================================================
// 串口接收
//==============================================================================

module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter UART_BPS = 9600
)(
    input              rx_clk,
    input              rx_rst_n,
    input              rx_in_data,
    output reg         rx_done,
    output reg [7:0]   rx_data
);

    localparam BAUD_CNT_MAX = CLK_FREQ / UART_BPS;

    reg rxd_d1, rxd_d2, rxd_d3;
    reg work_en;
    reg bit_flag;
    reg [15:0] baud_cnt;
    reg [3:0] bit_cnt;
    reg [7:0] rx_data_buf;
    reg rx_flag;

    wire start_en = ~rxd_d2 && rxd_d3;

    always @(posedge rx_clk or negedge rx_rst_n) begin
        if (!rx_rst_n) begin
            rxd_d1 <= 1;
            rxd_d2 <= 1;
            rxd_d3 <= 1;
        end else begin
            rxd_d1 <= rx_in_data;
            rxd_d2 <= rxd_d1;
            rxd_d3 <= rxd_d2;
        end
    end

    always @(posedge rx_clk or negedge rx_rst_n) begin
        if (!rx_rst_n)
            work_en <= 0;
        else if (start_en)
            work_en <= 1;
        else if (((bit_cnt == 4'd8) && bit_flag) || rx_done)
            work_en <= 0;
        else
            work_en <= work_en;
    end

    always @(posedge rx_clk or negedge rx_rst_n) begin
        if (!rx_rst_n)
            baud_cnt <= 0;
        else if (work_en == 0 || (baud_cnt == BAUD_CNT_MAX - 1))
            baud_cnt <= 0;
        else if (work_en)
            baud_cnt <= baud_cnt + 1;
        else
            baud_cnt <= baud_cnt;
    end

    always @(posedge rx_clk or negedge rx_rst_n) begin
        if (!rx_rst_n)
            bit_flag <= 0;
        else if (baud_cnt == BAUD_CNT_MAX / 2 - 1)
            bit_flag <= 1;
        else
            bit_flag <= 0;
    end

    always @(posedge rx_clk or negedge rx_rst_n) begin
        if (!rx_rst_n)
            bit_cnt <= 0;
        else if (bit_flag) begin
            if (bit_cnt == 4'd8)
                bit_cnt <= 0;
            else
                bit_cnt <= bit_cnt + 1;
        end else
            bit_cnt <= bit_cnt;
    end

    always @(posedge rx_clk or negedge rx_rst_n) begin
        if (!rx_rst_n)
            rx_data_buf <= 0;
        else if (bit_flag) begin
            case (bit_cnt)
                4'd1: rx_data_buf[0] <= rxd_d3;
                4'd2: rx_data_buf[1] <= rxd_d3;
                4'd3: rx_data_buf[2] <= rxd_d3;
                4'd4: rx_data_buf[3] <= rxd_d3;
                4'd5: rx_data_buf[4] <= rxd_d3;
                4'd6: rx_data_buf[5] <= rxd_d3;
                4'd7: rx_data_buf[6] <= rxd_d3;
                4'd8: rx_data_buf[7] <= rxd_d3;
                default: rx_data_buf <= rx_data_buf;
            endcase
        end
    end

    always @(posedge rx_clk or negedge rx_rst_n) begin
        if (!rx_rst_n)
            rx_flag <= 0;
        else if (bit_cnt == 4'd8 && bit_flag)
            rx_flag <= 1;
        else
            rx_flag <= 0;
    end

    always @(posedge rx_clk or negedge rx_rst_n) begin
        if (!rx_rst_n)
            rx_data <= 0;
        else if (rx_flag)
            rx_data <= rx_data_buf;
    end

    always @(posedge rx_clk or negedge rx_rst_n) begin
        if (!rx_rst_n)
            rx_done <= 0;
        else
            rx_done <= rx_flag;
    end

endmodule
