module FragFetcher(
                   clk,
                   rstn,
                   i_idxs, //-- From Sorter
                   i_idxs_ready, //-- From Sorter
                   i_req, //-- From Broadcaster
                   o_final_frag, //-- To Broadcaster
                   o_ready, //-- To Broadcaster
                   o_frag_req, //-- To DB
                   o_frag_idx, //-- To DB
                   o_done, //-- To DB
                   i_frag, //-- From DB
                   i_frag_ready, //--From DB
                   );

   parameter  BYTE               = 8;
   parameter  COMPRESSION_FACTOR = 16;
   localparam INDEX_LENGTH       = 2*BYTE; //-- in bits.
   parameter  LOG2_FRAGMENT_SIZE = 8;
   localparam FRAGMENT_SIZE      = 2**LOG2_FRAGMENT_SIZE;

   //-- assign o_final_frag[g] = frags[((idxs[(idxs_ptr-1) % COMPRESSION_FACTOR] % FRAGMENT_SIZE) + g) >= FRAGMENT_SIZE][(idxs[(idxs_ptr-1) % COMPRESSION_FACTOR] + g) % FRAGMENT_SIZE];
   //-- state params

   input wire                                   clk;
   input wire                                   rstn;

   input wire [COMPRESSION_FACTOR-1:0][INDEX_LENGTH-1:0] i_idxs;
   input wire                                            i_idxs_ready;

   input wire                                            i_req;
   output wire [FRAGMENT_SIZE-1:0][BYTE-1:0]             o_final_frag;
   output wire                                           o_ready;

   output wire                                           o_frag_req;
   output wire [INDEX_LENGTH-1:0]                        o_frag_idx;
   output reg                                            o_done;

   input wire [FRAGMENT_SIZE-1:0][BYTE-1:0]              i_frag;
   input wire                                            i_frag_ready;

   //-- Internal registers
   reg [INDEX_LENGTH-1:0]                                idxs[COMPRESSION_FACTOR-1:0];
   reg [INDEX_LENGTH-1:0]                                idxs_ptr;
   reg                                                   idxs_ready;
   reg [FRAGMENT_SIZE-1:0][BYTE-1:0]                     frags[1:0];
   reg [1:0]                                             rcv_cnt;
   reg                                                   handling_req;
   reg                                                   req_pending;

   /*
    initial begin
    idxs_ready <= 0;
    rcv_cnt <= 0;
    handling_req <= 0;
    req_pending <= 0;
    idxs_ptr <= 0;
    o_done <= 0;
   end
    */

   assign o_frag_req = !req_pending && (handling_req && rcv_cnt < 2 && idxs_ready);
   assign o_ready = rcv_cnt > 1;
   assign o_final_frag = (frags[0] << idxs[idxs_ptr] * BYTE) | (frags[1] >> (FRAGMENT_SIZE - idxs[idxs_ptr]) * BYTE);
   assign o_frag_idx = idxs[idxs_ptr];


   integer                                               i;
   always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
         idxs_ready   <= 0;
         rcv_cnt      <= 0;
         handling_req <= 0;
         req_pending  <= 0;
         idxs_ptr     <= 0;
         o_done       <= 0;
      end
      else begin
         if (i_idxs_ready) begin
            for (i = 0; i < COMPRESSION_FACTOR; i = i + 1) begin
               idxs[i]    <= i_idxs[i];
               idxs_ready <= 1;
               idxs_ptr   <= 0;
            end
         end
         if (i_req) begin//-- if you recieved a request, signal to start handling it
            handling_req <= 1;
         end

         if (o_frag_req) begin
            req_pending <= 1;
         end

         if (i_frag_ready && handling_req) begin //-- if you recieve a return for your request (o_frag_req)
            rcv_cnt           <= rcv_cnt + 1;
            frags[rcv_cnt[0]] <= i_frag;
            req_pending       <= 0;
         end

         if (rcv_cnt > 1 && handling_req) begin //-- Done handling the request
            rcv_cnt      <= 0;
            handling_req <= 0;
            if (idxs_ptr >= COMPRESSION_FACTOR-1) begin
               idxs_ready <= 0;
               o_done     <= 1;
            end else begin
               idxs_ptr <= idxs_ptr + 1;
            end
         end

         if (o_done) begin
            o_done <= 0;
         end
      end // else: !if(!rstn)
   end // always @ (posedge clk or negedge rstn)

endmodule
