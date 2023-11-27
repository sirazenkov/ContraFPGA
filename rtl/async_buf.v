
module async_buf #(
   parameter DATA_WIDTH = 8,
   parameter DEPTH      = 1
)(
   input                   isrc_rst_n,
   input                   isrc_clk,
   input                   isrc_wr,
   input [DATA_WIDTH-1:0]  isrc_data,

   input                   idst_rst_n,
   input                   idst_clk,
   input                   idst_rd,
   output [DATA_WIDTH-1:0] odst_data
);

   reg [DATA_WIDTH-1:0] buffer [0:DEPTH-1];

   reg [$clog2(DEPTH)-1:0] read_addr, write_addr;

   always @(posedge isrc_clk or negedge isrc_rst_n) begin
      if (!isrc_rst_n)
         write_addr <= {$clog2(DEPTH){1'b0}};
      else if (isrc_wr && (write_addr != (read_addr-1)))
         write_addr = write_addr + 1'b1;
   end

   always @(posedge idst_clk or negedge idst_rst_n) begin
      if (!idst_rst_n)
         read_addr <= {$clog2(DEPTH){1'b0}};
      else if (idst_rd && (read_addr != (write_addr-1)))
         read_addr = read_addr + 1'b1;
   end

   always @(posedge isrc_clk)
      if (isrc_wr) buffer[write_addr] <= isrc_data;

   assign odst_data = buffer[read_addr];

endmodule
