
module bin_buf #(
   parameter DATA_WIDTH = 8
)(
   input                   irst_n,
   input                   iclk,
   input [DATA_WIDTH-1:0]  idata,
   input                   iwr,

   output [DATA_WIDTH-1:0] odata
);

   reg [DATA_WIDTH-1:0] buffer [0:1];
   reg                  addr;

   always @(posedge iclk or negedge irst_n) begin
      if (!irst_n)  addr <= 1'b0;
      else if (iwr) addr <= ~addr;
   end

   always @(posedge iclk)
      if (iwr) buffer[addr] <= idata;

   assign odata = buffer[~addr];

endmodule
