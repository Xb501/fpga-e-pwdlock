//==============================================================================
// 串口发送
//==============================================================================
module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter UART_BPS = 9600
)(
    input              tx_clk,
    input              tx_rst_n,
    input      [7:0]   tx_in_data,
    input              tx_enable,
    output reg         tx_data_ready,
    output reg         tx_out_data
);

    localparam BAUD_CNT_MAX = CLK_FREQ / UART_BPS;

    reg [15:0] baud_cnt;
    reg [3:0]  data_bit_count;
    reg        transmission_ready;

    always @(posedge tx_clk or negedge tx_rst_n) begin
        if (!tx_rst_n)
            transmission_ready <= 0;
        else if (tx_enable)
            transmission_ready <= 1;
        else if ((baud_cnt == 16'd1) && (data_bit_count == 4'd9))
            transmission_ready <= 0;
        else
            transmission_ready <= transmission_ready;
    end

    always @(posedge tx_clk or negedge tx_rst_n) begin
        if (!tx_rst_n)
            baud_cnt <= 0;
        else if (baud_cnt == BAUD_CNT_MAX - 1)
            baud_cnt <= 0;
        else if (transmission_ready)
            baud_cnt <= baud_cnt + 1;
        else
            baud_cnt <= baud_cnt;
    end

    always @(posedge tx_clk or negedge tx_rst_n) begin
        if (!tx_rst_n)
            data_bit_count <= 0;
        else if (baud_cnt == 16'd1) begin
            if (transmission_ready)
                data_bit_count <= data_bit_count + 1;
            else if (data_bit_count == 4'd9)
                data_bit_count <= 0;
        end else
            data_bit_count <= data_bit_count;
    end

    always @(posedge tx_clk or negedge tx_rst_n) begin
        if (!tx_rst_n)
            tx_out_data <= 1;
        else if (baud_cnt == 16'd1) begin
            case (data_bit_count)
                4'd0: tx_out_data <= 0;
                4'd1: tx_out_data <= tx_in_data[0];
                4'd2: tx_out_data <= tx_in_data[1];
                4'd3: tx_out_data <= tx_in_data[2];
                4'd4: tx_out_data <= tx_in_data[3];
                4'd5: tx_out_data <= tx_in_data[4];
                4'd6: tx_out_data <= tx_in_data[5];
                4'd7: tx_out_data <= tx_in_data[6];
                4'd8: tx_out_data <= tx_in_data[7];
                4'd9: tx_out_data <= 1;
                default: tx_out_data <= 1;
            endcase
        end
    end

    always @(posedge tx_clk or negedge tx_rst_n) begin
        if (!tx_rst_n)
            tx_data_ready <= 0;
        else if (baud_cnt == 16'd1 && data_bit_count == 4'd9)
            tx_data_ready <= 1;
        else
            tx_data_ready <= 0;
    end

endmodule