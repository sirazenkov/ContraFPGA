module top (
  input        iclk, //27Mhz
  input        irst_n,

  input        iswitch_n,
  output       oprocessing,

  // SCCB interface
  inout        SDA,
  inout        SCL,

  // OV2640 camera
  input        VSYNC,
  input        HREF,
  input  [7:0] PIXDATA,
  input        PIXCLK,
  output       XCLK,
  
  // HyperRAM
  output [0:0] O_hpram_ck,
  output [0:0] O_hpram_ck_n,
  output [0:0] O_hpram_cs_n,
  output [0:0] O_hpram_reset_n,
  inout  [7:0] IO_hpram_dq,
  inout  [0:0] IO_hpram_rwds,
  
  // HDMI
  output       O_tmds_clk_p,
  output       O_tmds_clk_n,
  output [2:0] O_tmds_data_p, //{r,g,b}
  output [2:0] O_tmds_data_n   
);

//==================================================

  reg  [7:0]  pixdata_d1;
  reg         hcnt;
  wire [15:0] cam_data;

//-------------------------
//frame buffer in

  wire        ch0_vfb_clk_in;
  wire        ch0_vfb_vs_in;
  wire        ch0_vfb_de_in;
  wire [15:0] ch0_vfb_data_in;

//-------------------
//syn_code

  wire syn_off0_re; // ofifo read enable signal
  wire syn_off0_vs;
  wire syn_off0_hs;
            
  wire        off0_syn_de;
  wire [15:0] off0_syn_data;

//-------------------------------------
//HyperRAM

  wire dma_clk;
  wire memory_clk;
  wire mem_pll_lock;

//-------------------------------------------------
//memory interface

  wire        cmd;
  wire        cmd_en;
  wire [21:0] addr;          //[ADDR_WIDTH-1:0]
  wire [31:0] wr_data;       //[DATA_WIDTH-1:0]
  wire [3:0]  data_mask;
  wire        rd_data_valid;
  wire [31:0] rd_data;       //[DATA_WIDTH-1:0]
  wire        init_calib;

//------------------------------------------
//rgb data

  wire       rgb_vs_raw;
  wire       rgb_hs_raw;
  wire       rgb_de_raw;
  wire [7:0] intensity_data_raw;

  wire       rgb_vs_stretch;
  wire       rgb_hs_stretch;
  wire       rgb_de_stretch;
  wire [7:0] intensity_data_stretch;

  wire       rgb_vs;
  wire       rgb_hs;
  wire       rgb_de;
  wire [7:0] intensity_data; 

//------------------------------------
//HDMI TX
  
  wire serial_clk;
  wire pll_lock;
  wire hdmi_rst_n;
  wire pix_clk;
  wire clk_20M;

//===================================================

  reg switch_reg, switch_strobe;
  reg process;
  
  always @(posedge iclk) begin
    if (!irst_n) begin
      switch_reg    <= 1'b0;
      switch_strobe <= 1'b0;
    end else begin
      switch_reg    <= iswitch_n;
      switch_strobe <= switch_reg & !iswitch_n;
    end
  end
  always @(posedge iclk) begin
    if      (!irst_n)       process <= 1'b0;
    else if (switch_strobe) process <= ~process;
  end

  assign oprocessing = process;

  stretch stretch_inst (
    .isrc_rst_n(irst_n                ),
    .isrc_clk  (ch0_vfb_clk_in        ),
    .isrc_data (ch0_vfb_data_in[7:0]  ),
    .isrc_vs   (ch0_vfb_vs_in         ),
    .isrc_de   (ch0_vfb_de_in         ),

    .idst_rst_n(hdmi_rst_n            ),
    .idst_clk  (pix_clk               ),
    .idst_data (intensity_data_raw    ),
    .idst_vs   (rgb_vs_raw            ),
    .idst_hs   (rgb_hs_raw            ),
    .idst_de   (rgb_de_raw            ),

    .odst_data (intensity_data_stretch),
    .odst_vs   (rgb_vs_stretch        ),
    .odst_hs   (rgb_hs_stretch        ),
    .odst_de   (rgb_de_stretch        )
  );

//===================================================

  assign XCLK = clk_20M;

  OV2640_Controller u_OV2640_Controller (
    .clk            (clk_20M), // 24Mhz clock signal
    .resend         (1'b0   ), // Reset signal
    .config_finished(       ), // Flag to indicate that the configuration is finished
    .sioc           (SCL    ), // SCCB interface - clock signal
    .siod           (SDA    ), // SCCB interface - data signal
    .reset          (       ), // RESET signal for OV7670
    .pwdn           (       )  // PWDN signal for OV7670
  );

  always @(posedge PIXCLK or negedge irst_n) begin //iclk
    if (!irst_n)
      pixdata_d1 <= 8'd0;
    else
      pixdata_d1 <= PIXDATA;
  end

  always @(posedge PIXCLK or negedge irst_n) begin //iclk
    if (!irst_n)
      hcnt <= 1'd0;
    else if (HREF)
      hcnt <= ~hcnt;
    else
      hcnt <= 1'd0;
  end

  assign cam_data = {8'd0, pixdata_d1}; //Y8

//==============================================
//data width 16bit

  assign ch0_vfb_clk_in  = PIXCLK;       
  assign ch0_vfb_vs_in   = VSYNC;    //negative
  assign ch0_vfb_de_in   = HREF;     //hcnt;  
  assign ch0_vfb_data_in = cam_data; //Y8

//=====================================================
//SRAM

  video_frame_buffer video_frame_buffer_inst ( 
    .I_rst_n           (init_calib     ), //rst_n
    .I_dma_clk         (dma_clk        ), //sram_clk
    // video data input
    .I_vin0_clk        (ch0_vfb_clk_in ),
    .I_vin0_vs_n       (ch0_vfb_vs_in  ),
    .I_vin0_de         (ch0_vfb_de_in  ),
    .I_vin0_data       (ch0_vfb_data_in),
    .O_vin0_fifo_full  (               ),
    // video data output
    .I_vout0_clk       (pix_clk        ),
    .I_vout0_vs_n      (~syn_off0_vs   ),
    .I_vout0_de        (syn_off0_re    ),
    .O_vout0_den       (off0_syn_de    ),
    .O_vout0_data      (off0_syn_data  ),
    .O_vout0_fifo_empty(               ),
    // ddr write request
    .O_cmd             (cmd            ),
    .O_cmd_en          (cmd_en         ),
    .O_addr            (addr           ), //[ADDR_WIDTH-1:0]
    .O_wr_data         (wr_data        ), //[DATA_WIDTH-1:0]
    .O_data_mask       (data_mask      ),
    .I_rd_data_valid   (rd_data_valid  ),
    .I_rd_data         (rd_data        ), //[DATA_WIDTH-1:0]
    .I_init_calib      (init_calib     )
  );

//================================================
//HyperRAM ip

  GW_PLLVR GW_PLLVR_inst (
    .clkout(memory_clk  ), //output clkout
    .lock  (mem_pll_lock), //output lock
    .clkin (iclk        )  //input clkin
  );

  HyperRAM_Memory_Interface_Top HyperRAM_Memory_Interface_Top_inst (
    .clk            (iclk           ),
    .memory_clk     (memory_clk     ),
    .pll_lock       (mem_pll_lock   ),
    .rst_n          (irst_n         ),
    .O_hpram_ck     (O_hpram_ck     ),
    .O_hpram_ck_n   (O_hpram_ck_n   ),
    .IO_hpram_rwds  (IO_hpram_rwds  ),
    .IO_hpram_dq    (IO_hpram_dq    ),
    .O_hpram_reset_n(O_hpram_reset_n),
    .O_hpram_cs_n   (O_hpram_cs_n   ),
    .wr_data        (wr_data        ),
    .rd_data        (rd_data        ),
    .rd_data_valid  (rd_data_valid  ),
    .addr           (addr           ),
    .cmd            (cmd            ),
    .cmd_en         (cmd_en         ),
    .clk_out        (dma_clk        ),
    .data_mask      (data_mask      ),
    .init_calib     (init_calib     )
  ); 

//================================================

  wire out_de;
  syn_gen # (                 // 800x600  // 1024x768  // 1280x720
    .H_TOTAL (1056),          // 1056     // 1344      // 1650
    .H_SYNC  (128 ),          // 128      // 136       // 40
    .H_BPORCH(88  ),          // 88       // 160       // 220
    .H_RES   (800 ),          // 800      // 1024      // 1280
    .V_TOTAL (628 ),          // 628      // 806       // 750
    .V_SYNC  (4   ),          // 4        // 6         // 5
    .V_BPORCH(23  ),          // 23       // 29        // 20
    .V_RES   (600 ),          // 600      // 768       // 720
    .RD_HRES (640 ),
    .RD_VRES (480 ),
    .HS_POL  (1'b1), //HS polarity: 0 - neg.polarity，1 - pos.polarity
    .VS_POL  (1'b1)  //VS polarity: 0 - neg.polarity，1 - pos.polarity
  ) syn_gen_inst (
    .I_pxl_clk (pix_clk    ), //40MHz      //65MHz      //74.25MHz
    .I_rst_n   (hdmi_rst_n ),
    .O_rden    (syn_off0_re),
    .O_de      (out_de     ),
    .O_hs      (syn_off0_hs),
    .O_vs      (syn_off0_vs)
  );

localparam N = 5; //delay N clocks

  reg [N-1:0] Pout_hs_dn;
  reg [N-1:0] Pout_vs_dn;
  reg [N-1:0] Pout_de_dn;

  always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin                          
      Pout_hs_dn <= {N{1'b1}};
      Pout_vs_dn <= {N{1'b1}}; 
      Pout_de_dn <= {N{1'b0}}; 
    end else begin                          
      Pout_hs_dn <= {Pout_hs_dn[N-2:0], syn_off0_hs};
      Pout_vs_dn <= {Pout_vs_dn[N-2:0], syn_off0_vs}; 
      Pout_de_dn <= {Pout_de_dn[N-2:0], out_de}; 
    end
  end

//==============================================================================
//TMDS TX

  assign intensity_data_raw = off0_syn_de ? off0_syn_data[7:0] : 8'h00; // intensity
  assign rgb_vs_raw         = Pout_vs_dn[4]; // syn_off0_vs;
  assign rgb_hs_raw         = Pout_hs_dn[4]; // syn_off0_hs;
  assign rgb_de_raw         = Pout_de_dn[4]; // off0_syn_de;

  assign intensity_data = process ? intensity_data_stretch : intensity_data_raw;
  assign rgb_vs         = process ? rgb_vs_stretch         : rgb_vs_raw;
  assign rgb_hs         = process ? rgb_hs_stretch         : rgb_hs_raw;
  assign rgb_de         = process ? rgb_de_stretch         : rgb_de_raw;

  TMDS_PLLVR TMDS_PLLVR_inst (
    .clkin  (iclk      ), //input clk 
    .clkout (serial_clk), //output clk 
    .clkoutd(clk_20M   ), //output clkoutd
    .lock   (pll_lock  )  //output lock
  );

  assign hdmi_rst_n = irst_n & pll_lock;

  CLKDIV u_clkdiv (
    .RESETN(hdmi_rst_n),
    .HCLKIN(serial_clk), //clk x5
    .CLKOUT(pix_clk   ), //clk x1
    .CALIB (1'b1      )
  );
  defparam u_clkdiv.DIV_MODE="5";

  DVI_TX_Top DVI_TX_Top_inst (
    .I_rst_n      (hdmi_rst_n    ), //asynchronous reset, low active
    .I_serial_clk (serial_clk    ),
    .I_rgb_clk    (pix_clk       ), //pixel clock
    .I_rgb_vs     (rgb_vs        ), 
    .I_rgb_hs     (rgb_hs        ),    
    .I_rgb_de     (rgb_de        ), 
    .I_rgb_r      (intensity_data),  
    .I_rgb_g      (intensity_data),  
    .I_rgb_b      (intensity_data),  
    .O_tmds_clk_p (O_tmds_clk_p  ),
    .O_tmds_clk_n (O_tmds_clk_n  ),
    .O_tmds_data_p(O_tmds_data_p ), //{r,g,b}
    .O_tmds_data_n(O_tmds_data_n )
  );

endmodule
