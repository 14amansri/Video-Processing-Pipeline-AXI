
// ============================================================================
// 3. ASYNC FIFO (Clock Domain Crossing)
// ============================================================================
module axis_async_fifo #(
    parameter DATA_WIDTH = 24,
    parameter DEPTH = 1024
)(
    input  wire                  wr_clk,
    input  wire                  wr_reset_n,
    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                  s_axis_tvalid,
    input  wire                  s_axis_tlast,
    input  wire                  s_axis_tuser,
    output wire                  s_axis_tready, // Ignored by camera usually
    
    input  wire                  rd_clk,
    input  wire                  rd_reset_n,
    output reg [DATA_WIDTH-1:0]  m_axis_tdata,
    output reg                   m_axis_tvalid,
    output reg                   m_axis_tlast,
    output reg                   m_axis_tuser,
    input  wire                  m_axis_tready
);
    // Note: This is a simplified behavioral model. 
    // In production, use vendor-specific IP (xpm_fifo_async) for safety.
    
    reg [DATA_WIDTH+1:0] mem [0:DEPTH-1]; // +2 bits for last/user
    reg [9:0] wr_ptr = 0;
    reg [9:0] rd_ptr = 0;
    reg [9:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;
    reg [9:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;
    
    // Write Logic
    always @(posedge wr_clk) begin
        if (s_axis_tvalid) begin
            mem[wr_ptr] <= {s_axis_tuser, s_axis_tlast, s_axis_tdata};
            wr_ptr <= wr_ptr + 1;
        end
    end
    
    // Read Logic
    always @(posedge rd_clk or negedge rd_reset_n) begin
        if (!rd_reset_n) begin
            m_axis_tvalid <= 0;
            rd_ptr <= 0;
        end else begin
            // If output is ready and we have data (simplified empty check)
            if (m_axis_tready && (rd_ptr != wr_ptr_gray_sync2)) begin
                {m_axis_tuser, m_axis_tlast, m_axis_tdata} <= mem[rd_ptr];
                m_axis_tvalid <= 1;
                rd_ptr <= rd_ptr + 1;
            end else if (m_axis_tready) begin
                m_axis_tvalid <= 0;
            end
        end
    end
    
    // (Omitted: Full Gray Code synchronization logic for brevity, 
    // assumed present for safe pointer exchange in real synthesis)
    
endmodule

/*For zynq 7k, replace the axis_async_fifo module with this code - Aman and test this
  since async fifo module only run on PL and might crash since its not complex enough to handle when moving btw PCLK (camera clk) and system clk 

// Xilinx Parameterized Macro for Async FIFO
   xpm_fifo_async #(
      .FIFO_MEMORY_TYPE("auto"),
      .FIFO_WRITE_DEPTH(2048),
      .WRITE_DATA_WIDTH(DATA_WIDTH+2), // Data + User + Last
      .READ_MODE("fwft"), // First-Word-Fall-Through (Low latency)
      .CDC_SYNC_STAGES(2)
   ) xpm_fifo_inst (
      .rst(!wr_reset_n),
      .wr_clk(wr_clk),
      .wr_en(s_axis_tvalid),
      .din({s_axis_tuser, s_axis_tlast, s_axis_tdata}),
      .rd_clk(rd_clk),
      .rd_en(m_axis_tready),
      .dout({m_axis_tuser, m_axis_tlast, m_axis_tdata}),
      .empty(fifo_empty),
      .full(fifo_full)
   );
   
   assign s_axis_tready = !fifo_full;
   assign m_axis_tvalid = !fifo_empty;

*/

