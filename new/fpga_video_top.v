/*
 * ============================================================================
 * OV2640 REAL-TIME VIDEO PROCESSING PIPELINE (640x480)
 * ============================================================================
 * * ARCHITECTURE:
 * [OV2640 Sensor] 
 * | (8-bit Parallel DVP @ PCLK)
 * v
 * [Module: Capture & Expand] -> Converts 2 bytes RGB565 to 1 pixel RGB888 (AXIS)
 * | (AXIS Stream @ PCLK)
 * v
 * [Module: Async FIFO] -> Crossing from Camera Clock to System Clock
 * | (AXIS Stream @ SYS_CLK)
 * v
 * [Module: RGB to Gray]
 * v
 * [Module: Gaussian Blur] -> Uses 3x3 Window Buffer
 * v
 * [Module: Sobel Edge] -> Uses 3x3 Window Buffer
 * v
 * [Output] -> To HDMI/VGA Controller
 *
Gemini Link : https://gemini.google.com/share/54c79ab00491
 
To run this on zynq 7k

Connect the OV2640 SCL and SDA pins to the Zynq PS (Processor System) pins or EMIO pins.

Write a simple C program (in Vitis/SDK) to run on the ARM processor.

The C program sends the "Init Sequence" to the camera via I2C at startup.

Once configured, the camera starts blasting pixels to your Verilog PL pipeline.
 
 */

`timescale 1ns / 1ps

// ============================================================================
// 1. TOP LEVEL WRAPPER
// ============================================================================
module fpga_video_top (
    input  wire       sys_clk,      // System Clock (e.g., 100MHz)
    input  wire       sys_reset_n,  // System Reset (Active Low)
    
    // Physical Camera Interface (Connect to Pins)
    input  wire       cam_pclk,     // Pixel Clock from OV2640
    input  wire       cam_vsync,    // Vertical Sync
    input  wire       cam_href,     // Horizontal Ref
    input  wire [7:0] cam_data,     // 8-bit Data lines
    
    // Output Interface (e.g., to VDMA or HDMI Controller)
    input  wire       m_axis_out_tready,
    output wire [7:0] m_axis_out_tdata,
    output wire       m_axis_out_tvalid,
    output wire       m_axis_out_tlast,
    output wire       m_axis_out_tuser
);

    // --- Signals ---
    
    // Capture -> FIFO (PCLK Domain)
    wire [23:0] cap_tdata;
    wire        cap_tvalid;
    wire        cap_tlast;
    wire        cap_tuser;
    
    // FIFO -> RGB2Gray (SYS_CLK Domain)
    wire [23:0] fifo_tdata;
    wire        fifo_tvalid, fifo_tready, fifo_tlast, fifo_tuser;

    // RGB2Gray -> Blur
    wire [7:0]  gray_tdata;
    wire        gray_tvalid, gray_tready, gray_tlast, gray_tuser;

    // Blur -> Sobel
    wire [7:0]  blur_tdata;
    wire        blur_tvalid, blur_tready, blur_tlast, blur_tuser;

    // --- Module Instantiation ---

    // 1. CAPTURE INTERFACE (Converts DVP to AXI-Stream RGB888)
    ov2640_capture_axis #(
        .WIDTH(640)
    ) capture_inst (
        .pclk(cam_pclk),
        .reset_n(sys_reset_n), // Assuming reset is async or synced to pclk elsewhere
        .vsync(cam_vsync),
        .href(cam_href),
        .d(cam_data),
        .m_axis_tdata(cap_tdata),
        .m_axis_tvalid(cap_tvalid),
        .m_axis_tlast(cap_tlast),
        .m_axis_tuser(cap_tuser)
    );

    // 2. ASYNC FIFO (Clock Domain Crossing: PCLK -> SYS_CLK)
    // NOTE: In real FPGA, use Xilinx/Intel FIFO Macro for robustness.
    // This is a behavioral model for synthesis/simulation.
    axis_async_fifo #(
        .DATA_WIDTH(24),
        .DEPTH(1024)
    ) cdc_fifo (
        // Write Side (Camera Clock)
        .wr_clk(cam_pclk),
        .wr_reset_n(sys_reset_n),
        .s_axis_tdata(cap_tdata),
        .s_axis_tvalid(cap_tvalid),
        .s_axis_tlast(cap_tlast),
        .s_axis_tuser(cap_tuser),
        .s_axis_tready(), // Capture module doesn't respect backpressure (real-time)
        
        // Read Side (System Clock)
        .rd_clk(sys_clk),
        .rd_reset_n(sys_reset_n),
        .m_axis_tdata(fifo_tdata),
        .m_axis_tvalid(fifo_tvalid),
        .m_axis_tlast(fifo_tlast),
        .m_axis_tuser(fifo_tuser),
        .m_axis_tready(fifo_tready)
    );

    // 3. RGB TO GRAYSCALE
    axis_rgb_to_gray rgb2gray_inst (
        .clk(sys_clk),
        .reset_n(sys_reset_n),
        .s_axis_tdata(fifo_tdata),
        .s_axis_tvalid(fifo_tvalid),
        .s_axis_tready(fifo_tready), // Drives FIFO ready
        .s_axis_tlast(fifo_tlast),
        .s_axis_tuser(fifo_tuser),
        
        .m_axis_tdata(gray_tdata),
        .m_axis_tvalid(gray_tvalid),
        .m_axis_tready(gray_tready),
        .m_axis_tlast(gray_tlast),
        .m_axis_tuser(gray_tuser)
    );

    // 4. GAUSSIAN BLUR (Noise Reduction)
    axis_gaussian_blur #(
        .WIDTH(640)
    ) blur_inst (
        .clk(sys_clk),
        .reset_n(sys_reset_n),
        .s_axis_tdata(gray_tdata),
        .s_axis_tvalid(gray_tvalid),
        .s_axis_tready(gray_tready),
        .s_axis_tlast(gray_tlast),
        .s_axis_tuser(gray_tuser),
        
        .m_axis_tdata(blur_tdata),
        .m_axis_tvalid(blur_tvalid),
        .m_axis_tready(blur_tready),
        .m_axis_tlast(blur_tlast),
        .m_axis_tuser(blur_tuser)
    );

    // 5. SOBEL EDGE DETECTION (Final Output)
    axis_sobel #(
        .WIDTH(640)
    ) sobel_inst (
        .clk(sys_clk),
        .reset_n(sys_reset_n),
        .s_axis_tdata(blur_tdata),
        .s_axis_tvalid(blur_tvalid),
        .s_axis_tready(blur_tready),
        .s_axis_tlast(blur_tlast),
        .s_axis_tuser(blur_tuser),
        
        .m_axis_tdata(m_axis_out_tdata),
        .m_axis_tvalid(m_axis_out_tvalid),
        .m_axis_tready(m_axis_out_tready),
        .m_axis_tlast(m_axis_out_tlast),
        .m_axis_tuser(m_axis_out_tuser)
    );

endmodule

