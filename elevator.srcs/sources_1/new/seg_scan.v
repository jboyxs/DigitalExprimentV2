// module seg_scan(
// input  clk,
// input [6:0] data_seg0,
// input [6:0] data_seg1,
// input [6:0] data_seg2,
// input [6:0] data_seg3,
// input [6:0] data_seg4,
// input [6:0] data_seg5,
// output reg [7:0] data_seg,
// output reg [5:0] data_dig
// );


// parameter clk_freq=50000000;//50Mhz
// parameter scan_freq=200;//200hz
// parameter scan_cont=clk_freq/scan_freq/2-1;

// reg [31:0] time_cont = 0;
// reg [2:0]  temp      = 3'd0;

// always@(posedge clk) begin
//     if(time_cont < scan_cont)
//         time_cont <= time_cont + 1;
//     else begin
//         time_cont <= 0;
//         temp      <= (temp == 3'd5) ? 3'd0 : temp + 1;
//     end
// end

// always@(posedge clk) begin
//     case(temp)
//         3'd0: begin data_seg <= {1'b0,data_seg0}; data_dig <= 6'b111110; end
//         3'd1: begin data_seg <= {1'b0,data_seg1}; data_dig <= 6'b111101; end
//         3'd2: begin data_seg <= {1'b0,data_seg2}; data_dig <= 6'b111011; end
//         3'd3: begin data_seg <= {1'b0,data_seg3}; data_dig <= 6'b110111; end
//         3'd4: begin data_seg <= {1'b0,data_seg4}; data_dig <= 6'b101111; end
//         3'd5: begin data_seg <= {1'b0,data_seg5}; data_dig <= 6'b011111; end
//         default: begin data_seg <= 8'hff; data_dig <= 6'b111111; end
//     endcase
// end
// endmodule



module seg_scan(
input  clk,
input [7:0] data_seg0,
input [7:0] data_seg1,
input [7:0] data_seg2,//扩展显示
input [7:0] data_seg3,//扩展显示
output reg [7:0] data_seg,
output reg [5:0] data_dig
);
parameter clk_freq=50000000;//50Mhz
parameter scan_freq=200;//200hz
parameter scan_cont=clk_freq/scan_freq/2-1;

reg [31:0] time_cont = 0;
reg [1:0]  temp      = 2'd0;

always@(posedge clk) begin
    if(time_cont < scan_cont)
        time_cont <= time_cont + 1;
    else begin
        time_cont <= 0;
        temp      <= (temp == 2'd3) ? 2'd0 : temp + 1;
    end
end

always@(posedge clk) begin
    case(temp)
        2'd0: begin data_seg <= data_seg0; data_dig <= 6'b111110; end
        2'd1: begin data_seg <= data_seg1; data_dig <= 6'b111101; end
        2'd2: begin data_seg <= data_seg2; data_dig <= 6'b111011; end
        2'd3: begin data_seg <= data_seg3; data_dig <= 6'b110111; end
        default: begin data_seg <= 8'hff; data_dig <= 6'b111111; end
    endcase
end
 
endmodule