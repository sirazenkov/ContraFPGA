
module contra #(
   parameter POLARITY = 1
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

   `ifdef COCOTB_SIM
    initial begin
      $dumpfile("contra_wave.vcd");
      $dumpvars(0, contra);
      #1;
    end
  `endif

   localparam PIPELINE_LEN = 10;

   reg  src_vs_reg;
   wire src_vs_strobe;

   reg [7:0] min_int, max_int;
   reg [7:0] range;

   reg [7:0] used_min_int, used_max_int;

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
   assign src_vs_strobe = (src_vs_reg != POLARITY) && (isrc_vs == POLARITY);

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

   always @ (posedge isrc_clk or negedge isrc_rst_n) begin
      if (!isrc_rst_n) begin
         range        <= 8'd0;
         used_min_int <= 8'd0;
         used_max_int <= 8'd0;
      end else if (src_vs_strobe) begin
         range        <= max_int - min_int;
         used_min_int <= min_int;
         used_max_int <= max_int;
      end
   end

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
