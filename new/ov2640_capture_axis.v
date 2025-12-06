
// ============================================================================
// 2. OV2640 CAPTURE MODULE (RGB565 -> RGB888) , For 640x480p Resolution
// ============================================================================
module ov2640_capture_axis #(
    parameter WIDTH = 640
)(
    input  wire        pclk,
    input  wire        reset_n,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  d,
    
    // AXI Stream Output (RGB888)
    output reg [23:0]  m_axis_tdata,
    output reg         m_axis_tvalid,
    output reg         m_axis_tlast,
    output reg         m_axis_tuser
);
    // OV2640 sends RGB565 as:
    // Cycle 1: R[4:0] G[5:3]
    // Cycle 2: G[2:0] B[4:0]
    
    reg        byte_toggle; // 0 = First byte, 1 = Second byte
    reg [7:0]  first_byte;
    reg [11:0] x_count;
    
    // Edge detection for VSYNC to handle TUSER (Frame Start)
    reg vsync_d;
    wire frame_start = (!vsync_d && vsync); // VSYNC Rising Edge (Active High usually)

    // --- FIX: Logic moved OUTSIDE the always block ---
    // These wires decode the RGB565 components from the captured 'first_byte' and current 'd'
    wire [4:0] r5 = first_byte[7:3];
    wire [5:0] g6 = {first_byte[2:0], d[7:5]};
    wire [4:0] b5 = d[4:0];
    
    always @(posedge pclk or negedge reset_n) begin
        if (!reset_n) begin
            byte_toggle <= 0;
            m_axis_tvalid <= 0;
            m_axis_tdata <= 0;
            x_count <= 0;
            vsync_d <= 0;
            m_axis_tuser <= 0;
            m_axis_tlast <= 0;
        end else begin
            vsync_d <= vsync;
            
            // If VSYNC active (Frame Blanking), reset counters
            if (vsync) begin
                byte_toggle <= 0;
                x_count <= 0;
                m_axis_tvalid <= 0;
                m_axis_tuser <= 0; // Will set high on first valid pixel
            end
            
            // Capture Data when HREF is High
            else if (href) begin
                if (byte_toggle == 0) begin
                    // First Byte: R[4:0], G[5:3]
                    first_byte <= d;
                    byte_toggle <= 1;
                    m_axis_tvalid <= 0; // Not ready yet, need 2nd byte
                end else begin
                    // Second Byte: G[2:0], B[4:0]
                    // We use the wires defined above which now contain the decoded values
                    
                    // Expand to RGB888 (24-bit)
                    // R8 = {R5, R5[4:2]}
                    // G8 = {G6, G6[5:4]}
                    // B8 = {B5, B5[4:2]}
                    
                    m_axis_tdata <= { {r5, r5[4:2]}, {g6, g6[5:4]}, {b5, b5[4:2]} };
                    m_axis_tvalid <= 1;
                    
                    // Handle TUSER (Start of Frame)
                    // High only for the very first pixel of the frame
                    if (x_count == 0 && frame_start_latched) 
                        m_axis_tuser <= 1;
                    else 
                        m_axis_tuser <= 0;

                    // Handle TLAST (End of Line)
                    if (x_count == WIDTH-1) begin
                        m_axis_tlast <= 1;
                        x_count <= 0;
                    end else begin
                        m_axis_tlast <= 0;
                        x_count <= x_count + 1;
                    end
                    
                    byte_toggle <= 0;
                end
            end else begin
                m_axis_tvalid <= 0;
                byte_toggle <= 0; // Reset byte alignment if HREF drops
            end
        end
    end
    
    // Latch frame start to ensure TUSER aligns with first valid pixel
    reg frame_start_latched;
    always @(posedge pclk or negedge reset_n) begin
        if(!reset_n) frame_start_latched <= 0;
        else if (frame_start) frame_start_latched <= 1;
        else if (m_axis_tvalid && m_axis_tuser) frame_start_latched <= 0;
    end

endmodule

