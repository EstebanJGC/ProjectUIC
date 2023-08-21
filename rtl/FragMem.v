module FragMem(
               clk,
               rstn,
               WnR,
               i_req,
               i_data,
               i_addr,
               o_data,
               o_ready
               );

   parameter               AW = 16;
   parameter					ODW = 256;
   parameter               BYTE = 8;
   localparam              RAM_INSTS = ODW / 32;

   input wire                 clk;
   input wire                 rstn;
   input wire                 WnR;
   input wire						i_req; //-- if some module is requesting data

   input wire [BYTE-1:0]      i_data;
   input wire [AW-1: 0]       i_addr;

   output wire [BYTE*ODW-1:0] o_data;
   output reg                 o_ready;

   //-- Internal wires
   wire [4:0]                 byte_addr;
   wire [2:0]                 inst_addr;
   wire [6:0]                 frag_addr;
   wire [(ODW/BYTE) - 1:0][BYTE-1:0] bweb;
   wire [255: 0]                     padded_data;

   assign byte_addr = i_addr[4:0];
   assign inst_addr = i_addr[7:5];
   assign frag_addr = i_addr[14:8];
   assign padded_data = i_data;

   /*
    This module wraps the SRAM memory instances
    Its logic is as follows:
    At each cycle it can ethier Write or Read data from the memory. It writes data in chunks of a byte at each cycle.
    If it recieves an address to read, it reads a fragment.
    When this module recieves a Write command, the address at which it writes is a byte address.
    When this module recieves a Read command, the address at which it reads is a fragment aligned address.
    */

/*
HERE YOUR MEMORY FROM YOUR MEMORY COMPILER
*/

   always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
         o_ready <= 1'b0;
      end
      else
        o_ready <= i_req && !WnR;
   end

endmodule
