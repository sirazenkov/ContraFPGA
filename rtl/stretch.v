
module stretch #(
   parameter SRC_POLARITY = 1,
   parameter DST_POLARITY = 1,
   parameter BUF_TYPE     = "ASYNC"
)(
   input        isrc_rst_n,
   input        isrc_clk,
   input  [7:0] isrc_data,
   input        isrc_vs,
   input        isrc_de,

   input        idst_rst_n,
   input        idst_clk,
   input  [7:0] idst_data,
   input        idst_vs,
   input        idst_hs,
   input        idst_de,

   output [7:0] odst_data,
   output       odst_vs,
   output       odst_hs,
   output       odst_de
);

   localparam PIPELINE_LEN = 10;

   reg  src_vs_reg;
   wire src_vs_strobe;

   reg  [7:0] min_int, max_int;

   wire [15:0] intensity, used_intensity;
   wire [7:0] used_min_int, used_max_int;
   wire [7:0] range;

   reg  dst_vs_reg;
   wire dst_vs_strobe;

   reg  [7:0]  dst_data_norm;
   wire [15:0] dst_data_mult;
   wire [7:0]  dst_data;

   reg [PIPELINE_LEN-1:0] dst_vs_pipeline;
   reg [PIPELINE_LEN-1:0] dst_hs_pipeline;
   reg [PIPELINE_LEN-1:0] dst_de_pipeline;

   always @ (posedge isrc_clk or negedge isrc_rst_n) begin
      if (!isrc_rst_n) src_vs_reg <= 1'b0;
      else             src_vs_reg <= isrc_vs;
   end
   assign src_vs_strobe = (src_vs_reg != SRC_POLARITY) && (isrc_vs == SRC_POLARITY);

   always @ (posedge isrc_clk or negedge isrc_rst_n) begin
      if (!isrc_rst_n) begin
         min_int <= 8'd255;
         max_int <= 8'd0;
      end else if (src_vs_strobe) begin
         min_int <= 8'd255;
         max_int <= 8'd0;
      end else if (isrc_de) begin
         if (isrc_data < min_int) min_int <= isrc_data;
         if (isrc_data > max_int) max_int <= isrc_data;
      end
   end

   always @ (posedge isrc_clk or negedge idst_rst_n) begin
      if (!idst_rst_n) dst_vs_reg <= 1'b0;
      else             dst_vs_reg <= idst_vs;
   end
   assign dst_vs_strobe = (dst_vs_reg != DST_POLARITY) && (idst_vs == DST_POLARITY);

   assign intensity = {max_int, min_int};

   generate
      if (BUF_TYPE == "BIN")
         bin_buf #(
            .DATA_WIDTH(16)
         ) bin_buf_inst (
            .irst_n(isrc_rst_n),
            .iclk  (isrc_clk),

            .idata (intensity),
            .iwr   (src_vs_strobe),

            .odata (used_intensity)
         );
      else
         async_buf #(
            .DATA_WIDTH(16),
            .DEPTH     ( 3)
         ) async_buf_inst (
            .isrc_rst_n(isrc_rst_n),
            .isrc_clk  (isrc_clk),

            .isrc_data (intensity),
            .isrc_wr   (src_vs_strobe),

            .idst_rst_n(idst_rst_n),
            .idst_clk  (idst_clk),
            .idst_rd   (dst_vs_strobe),
            .odst_data (used_intensity)
         );
   endgenerate
   assign used_max_int = used_intensity[15:8];
   assign used_min_int = used_intensity[7:0];
   assign range = used_max_int - used_min_int;

   always @ (posedge idst_clk or negedge idst_rst_n) begin
      if (!idst_rst_n)
         dst_data_norm <= 8'd0;
      else
         dst_data_norm <= idst_data - used_min_int;
   end

   mult255 mult255_inst (
      .iclk  (idst_clk),
      .irst_n(idst_rst_n),

      .x     (dst_data_norm),
      .q     (dst_data_mult)
   );

   divider divider_inst (
      .iclk     (idst_clk),
      .irst_n   (idst_rst_n),

      .idividend(dst_data_mult),
      .idivisor (range),

      .oquotient(dst_data)
   );

   always @ (posedge idst_clk or negedge idst_rst_n) begin
      if (!idst_rst_n) begin
         dst_vs_pipeline <= {PIPELINE_LEN{1'b0}};
         dst_hs_pipeline <= {PIPELINE_LEN{1'b0}};
         dst_de_pipeline <= {PIPELINE_LEN{1'b0}};
      end else begin
         dst_vs_pipeline <= {dst_vs_pipeline[PIPELINE_LEN-2:0], idst_vs};
         dst_hs_pipeline <= {dst_hs_pipeline[PIPELINE_LEN-2:0], idst_hs};
         dst_de_pipeline <= {dst_de_pipeline[PIPELINE_LEN-2:0], idst_de};
      end
   end

   assign odst_data = dst_data;
   assign odst_vs = dst_vs_pipeline[PIPELINE_LEN-1];
   assign odst_hs = dst_hs_pipeline[PIPELINE_LEN-1];
   assign odst_de = dst_de_pipeline[PIPELINE_LEN-1];

endmodule
