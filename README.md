<p align="justify">

## Integration Guide: Zynq-7000 & OV2640
This section details how to deploy this pipeline on a Zynq-7000 SoC. 
The Zynq architecture allows us to split tasks efficiently: the **Programmable Logic (PL)** handles the high-speed pixel stream, while the **Processing System (PS)** handles the slow camera configuration.
#### 1. Physical Connections
   Connect the OV2640 module to the FPGA Pmod headers.
   ## OV2640 → Zynq Pin Mapping

| OV2640 Pin | Zynq Port      | Description              | Direction | Note                                      |
|------------|----------------|--------------------------|-----------|-------------------------------------------|
| D0 - D7    | `cam_data[7:0]`| Parallel Video Data      | Input     |                                           |
| PCLK       | `cam_pclk`     | Pixel Clock              | Input     | Critical timing                           |
| HREF       | `cam_href`     | Horizontal Reference     | Input     |                                           |
| VSYNC      | `cam_vsync`    | Vertical Sync            | Input     |                                           |
| SIOC       | `I2C SCL`      | I2C Clock                | Output (PS) | Connect via EMIO to PS I2C               |
| SIOD       | `I2C SDA`      | I2C Data                 | Bi-dir (PS) | Connect via EMIO to PS I2C              |
| XCLK/MCLK  | `MCLK`         | Master Clock             | Output (PL) | FPGA must generate 24 MHz                |
| PWDN       | `pwdn`         | Power Down               | Output    | Drive Low (0)                             |
| RESET      | `reset`        | Reset                    | Output    | Drive High (1)                            |

#### 2. Vivado Block Design Strategy
  To implement this on the Zynq PL, follow this block design structure in Vivado:   
    <ul>
      <li>**ZYNQ7 Processing System**: Instantiate the ARM processor block. Enable **I2C0** (or I2C1) and route it to **EMIO** (Extended Multiplexed I/O). This allows the ARM processor to control the camera pins through the FPGA fabric.</li>
    <li> **Clocking Wizard**: </li><ul>
    <li>Input: `FCLK_CLK0`(from Zynq PS).</li></ul>
    <ul> <li>Output 1: `100MHz` (System Clock for the pipeline).</li></ul>
      <ul><li>Output 2: `24MHz` (Master Clock to feed the OV2640 `XCLK1` pin).</li></ul>
      <li>**Pipeline Instantiation:** Add the `ov2640_video_pipeline` module. Connect the `100MHz` clock to `sys_clk`.
      </li>
      <li>**Constraints (XDC):** Map the `cam_pclk` to a pin capable of clock input (MRCC/SRCC pins are preferred). If using a standard GPIO pin, you must add the following constraint to prevent build errors: 
        <pre>
<code class="language-tcl">
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_pclk_IBUF]
</code>
</pre>
        
#### 3. Software Configuration (Vitis/SDK)
The OV2640 will not output the correct format automatically. You must run a C program on the Zynq ARM Core to initialize the sensor via SCCB (I2C).

**Required Initialization Sequence:**
<li>Soft Reset: Write <code>0x80</code> to register <code>0x12</code>.</li>
<li>Resolution: Load the specific register struct for <b>VGA (640x480)</b>.</li>
<li>Pixel Format: Load the register struct for <b>RGB565</b>.</li>
<li>Test: Check the Product ID registers (<code>0x0A</code>, <code>0x0B</code>) to verify communication.</li>
 
 <i> Note: Without this step, the pipeline will likely receive YUV or Bayer Raw data, resulting in corrupted visual output.
</i>

#### 4. Video Output Path (Suggestion)
Since this pipeline outputs an AXI-Stream, you cannot connect it directly to an HDMI port. For visual output on a monitor, the recommended flow is:
 
 `Pipeline Output` → `AXI VDMA (Write Channel)` → `DDR3 Memory` → `AXI VDMA (Read Channel)` → `AXI4-Stream to Video Out` → `RGB to DVI/HDMI` → `Monitor`

This allows the VDMA to handle the frame buffering required to match the monitor's refresh rate (60Hz) with the camera's capture rate.


