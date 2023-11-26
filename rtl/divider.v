`timescale 1ns/100ps

module divider (
   input iclk,
   input irst_n,

   input  [15:0] idividend,
   input  [7:0]  idivisor,

   output [7:0]  oquotient
);

   `ifdef COCOTB_SIM
    initial begin
      $dumpfile("divider_wave.vcd");
      $dumpvars(0, divider);
      #1;
    end
  `endif

   integer i;

   reg [15:0] dividend_pipeline    [0:7];
   reg [7:0]  divisor_pipeline     [0:7];
   reg [7:0]  quotient_pipeline    [0:7];
   reg [15:0] divisor_pow_pipeline [0:7];
   reg [15:0] accum_pipeline       [0:7];
   reg        accept_pipeline      [0:7];

   always @(posedge iclk or negedge irst_n) begin
     if (!irst_n) begin
        for (i = 0; i < 8; i = i + 1) begin
           dividend_pipeline[i] <= 8'h00;
           quotient_pipeline[i] <= 8'h00;
           accum_pipeline   [i] <= 8'h00;
        end
     end else begin
        for (i = 0; i < 8; i = i + 1) begin
           if (i == 0) begin
              dividend_pipeline[i] <= idividend;
              divisor_pipeline [i] <= idivisor;
              quotient_pipeline[i] <= {accept_pipeline[i], 7'd0};
              accum_pipeline   [i] <= accept_pipeline[i] ? divisor_pow_pipeline[i] : 8'h00;
           end else begin
              dividend_pipeline[i] <= dividend_pipeline[i-1];
              divisor_pipeline [i] <= divisor_pipeline[i-1];
              quotient_pipeline[i] <= quotient_pipeline[i-1] | (accept_pipeline[i] << (7-i));
              accum_pipeline   [i] <= accept_pipeline[i] ? accum_pipeline[i-1] + divisor_pow_pipeline[i] : accum_pipeline[i-1];
           end
        end
     end
   end

   always @* begin
      for (i = 0; i < 8; i = i + 1) begin
         if (i == 0) begin
            divisor_pow_pipeline[i] = {1'b0, idivisor, 7'd0};
            accept_pipeline     [i] = divisor_pow_pipeline[i] <= idividend;
         end else begin
            divisor_pow_pipeline[i] = divisor_pow_pipeline[i-1] >> 1;
            accept_pipeline     [i] = (accum_pipeline[i-1] + divisor_pow_pipeline[i]) <= dividend_pipeline[i-1];
         end
      end
   end

   assign oquotient = quotient_pipeline[7];

endmodule
