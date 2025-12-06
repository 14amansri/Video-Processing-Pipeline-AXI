
// ============================================================================
// 5. WINDOW BUFFER (3x3) - 640px Width
// ============================================================================
module window_buffer_3x3 #(
    parameter WIDTH = 640
)(
    input  wire       clk,
    input  wire       ce, 
    input  wire [7:0] pixel_in,
    output wire [7:0] p11, p12, p13,
    output wire [7:0] p21, p22, p23,
    output wire [7:0] p31, p32, p33
);
    // BRAM inference for Line Buffers
    reg [7:0] line_buf0 [0:WIDTH-1];
    reg [7:0] line_buf1 [0:WIDTH-1];
    reg [9:0] wr_ptr = 0; // Log2(640) approx 10 bits

    reg [7:0] lb0_out, lb1_out;
    reg [7:0] win0[0:2], win1[0:2], win2[0:2];

    always @(posedge clk) begin
        if (ce) begin
            lb0_out <= line_buf0[wr_ptr];
            lb1_out <= line_buf1[wr_ptr];
            
            line_buf1[wr_ptr] <= pixel_in;
            line_buf0[wr_ptr] <= lb1_out;
            
            // Shift Window
            win0[2] <= lb0_out; win0[1] <= win0[2]; win0[0] <= win0[1];
            win1[2] <= lb1_out; win1[1] <= win1[2]; win1[0] <= win1[1];
            win2[2] <= pixel_in; win2[1] <= win2[2]; win2[0] <= win2[1];

            if (wr_ptr == WIDTH-1) wr_ptr <= 0;
            else wr_ptr <= wr_ptr + 1;
        end
    end

    assign p11=win0[0]; assign p12=win0[1]; assign p13=win0[2];
    assign p21=win1[0]; assign p22=win1[1]; assign p23=win1[2];
    assign p31=win2[0]; assign p32=win2[1]; assign p33=win2[2];
endmodule


