
// ============================================================================
// 4. RGB TO GRAYSCALE (24-bit -> 8-bit)
// ============================================================================
module axis_rgb_to_gray (
    input  wire        clk,
    input  wire        reset_n,
    input  wire [23:0] s_axis_tdata,
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
    assign s_axis_tready = m_axis_tready;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            m_axis_tvalid <= 0;
            m_axis_tdata <= 0;
        end else if (m_axis_tready) begin
            m_axis_tvalid <= s_axis_tvalid;
            m_axis_tlast  <= s_axis_tlast;
            m_axis_tuser  <= s_axis_tuser;
            
            if (s_axis_tvalid) begin
                // R=23:16, G=15:8, B=7:0
                // Gray = (R*77 + G*150 + B*29) >> 8
                m_axis_tdata <= (s_axis_tdata[23:16]*77 + s_axis_tdata[15:8]*150 + s_axis_tdata[7:0]*29) >> 8;
            end
        end
    end
endmodule

