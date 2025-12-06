// ============================================================================
// 6. GAUSSIAN BLUR
// ============================================================================
module axis_gaussian_blur #(
    parameter WIDTH = 640
)(
    input  wire        clk,
    input  wire        reset_n,
    input  wire [7:0]  s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    input  wire        s_axis_tuser,
    output reg [7:0]   m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg         m_axis_tlast,
    output reg         m_axis_tuser
);
    wire [7:0] p11, p12, p13, p21, p22, p23, p31, p32, p33;
    wire transaction = s_axis_tvalid && m_axis_tready;
    assign s_axis_tready = m_axis_tready;

    window_buffer_3x3 #(.WIDTH(WIDTH)) wb (
        .clk(clk), .ce(transaction), .pixel_in(s_axis_tdata),
        .p11(p11), .p12(p12), .p13(p13),
        .p21(p21), .p22(p22), .p23(p23),
        .p31(p31), .p32(p32), .p33(p33)
    );

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
             m_axis_tvalid <= 0;
             m_axis_tdata <= 0;
        end else if (m_axis_tready) begin
            m_axis_tvalid <= s_axis_tvalid;
            m_axis_tlast <= s_axis_tlast;
            m_axis_tuser <= s_axis_tuser;
            if (s_axis_tvalid) begin
                m_axis_tdata <= (p11 + 2*p12 + p13 + 2*p21 + 4*p22 + 2*p23 + p31 + 2*p32 + p33) >> 4;
            end
        end
    end
endmodule
