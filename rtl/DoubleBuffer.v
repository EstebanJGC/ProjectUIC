module DoubleBuffer(
                    clk,
                    rstn,
                    //// Hasher + Sorter pipeline (aka KMER pipeline)////
                    i_write_data_ready,
                    i_write_data,
                    i_write_data_done,
                    o_ready_to_rcv_write,
                    o_kmer, //-- the kmer value (goes into the hasher)
                    o_kmer_index, //-- the kmer index
                    o_kmer_ready, //-- Indicates weather the kmer and kmer index are ready.
                    o_kmer_done, //-- Indicates weather we are done Transmitting genomic data.
                    //// Extender Pipline (aka FRAGMENT pipeline) ////
                    i_addr,
                    i_read_data_ready,
                    i_read_data_done,
                    o_ready_to_rcv_read,
                    o_frag,
                    o_frag_ready
                    );

   parameter  BYTE               = 8;
   parameter  Rx_rate            = 1; //-- size in bytes.
   parameter  KMER_SIZE          = 16; //-- in bytes.
   parameter  LOG2_FRAGMENT_SIZE = 8;
   localparam FRAGMENT_SIZE      = 2**LOG2_FRAGMENT_SIZE;
   parameter  NUM_FRAGMENTS      = 128;
   parameter  INDEX_LENGTH       = 16; //-- in bits.

   input wire                       clk;
   input wire                       rstn;

   //-- KMER pipeline input
   input wire                       i_write_data_ready;
   input wire [Rx_rate-1:0][BYTE-1:0] i_write_data;
   input wire                         i_write_data_done;
   output wire                        o_ready_to_rcv_write;

   //-- KMER pipeline output
   output wire [KMER_SIZE-1:0][BYTE-1:0] o_kmer;
   output reg [INDEX_LENGTH-1:0]         o_kmer_index;
   output reg                            o_kmer_ready;
   output wire                           o_kmer_done;


   //-- FRAGMENT pipeline input
   input wire [INDEX_LENGTH-1:0]         i_addr;
   input wire                            i_read_data_ready;
   input wire                            i_read_data_done;
   output wire                           o_ready_to_rcv_read;

   //-- FRAGMENT pipeline output
   output wire [FRAGMENT_SIZE-1:0][BYTE-1:0] o_frag;
   output wire                               o_frag_ready;


   //-- Internal Wires
   wire                                      mem_req[1:0];
   wire                                      WnR[1:0];
   wire [INDEX_LENGTH-1:0]                   curr_addr[1:0];
   wire [FRAGMENT_SIZE-1:0][BYTE-1:0]        frag0;
   wire [FRAGMENT_SIZE-1:0][BYTE-1:0]        frag1;
   wire [1:0]                                frag_ready;


   //-- Internal HW
   reg                                       writer, reader;
   reg                                       writer_pending, reader_pending;
   reg [KMER_SIZE-1:0][BYTE-1:0]             kmer_buffer;
   reg [INDEX_LENGTH-1:0]                    curr_base_addr;



   assign mem_req[0] = (writer == 0 && !writer_pending && i_write_data_ready) || (reader == 0 && !reader_pending && i_read_data_ready);
   assign mem_req[1] = (writer == 1 && !writer_pending && i_write_data_ready) || (reader == 1 && !reader_pending && i_read_data_ready);
   assign WnR[0] = (writer == 0 && !writer_pending && i_write_data_ready);
   assign WnR[1] = (writer == 1 && !writer_pending && i_write_data_ready);
   assign o_ready_to_rcv_write = ~writer_pending;
   assign o_ready_to_rcv_read = ~reader_pending;
   assign curr_addr[0] = WnR[0] ? curr_base_addr : i_addr;
   assign curr_addr[1] = WnR[1] ? curr_base_addr : i_addr;
   assign o_kmer = kmer_buffer ;//>>> (curr_base_addr*BYTE % (16*BYTE));
   assign o_kmer_done = writer_pending;
   assign o_frag = (reader == 0) ? frag0 : frag1;
   assign o_frag_ready = (reader == 0) ? frag_ready[0] : frag_ready[1];

   //-- Create two chunks of memory
   genvar                                    i;
   generate
      FragMem frag_mem0(
                        .clk    (clk),
                        .rstn   (rstn),
                        .WnR    (WnR[0]),
                        .i_req  (mem_req[0]),
                        .i_data (i_write_data),
                        .i_addr (curr_addr[0]),
                        .o_data (frag0),
                        .o_ready(frag_ready[0])
                        );
      FragMem frag_mem1(
                        .clk    (clk),
                        .rstn   (rstn),
                        .WnR    (WnR[1]),
                        .i_req  (mem_req[1]),
                        .i_data (i_write_data),
                        .i_addr (curr_addr[1]),
                        .o_data (frag1),
                        .o_ready(frag_ready[1])
                        );
   endgenerate

   /*
    initial begin
    writer = 0;
    reader = 0;
    o_kmer_index = 0;
    o_kmer_ready = 0;
    writer_pending = 0;
    reader_pending = 1;
    curr_base_addr = 0;
end
    */

   always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
         writer         <= 0;
         reader         <= 0;
         o_kmer_index   <= 0;
         o_kmer_ready   <= 0;
         writer_pending <= 0;
         reader_pending <= 1;
         curr_base_addr <= 0;
      end

      else begin
         //-- FragMem logic
         if (writer_pending && reader == writer) begin
            writer <= ~writer;
            writer_pending <= 0;
            curr_base_addr <= 0;
         end
         if (reader_pending && reader != writer) begin
            reader_pending <= 0;
         end
         if (i_write_data_done) begin
            writer_pending <= 1;
         end
         if (i_read_data_done) begin
            reader <= ~reader;
            reader_pending <= 1;
         end

         //-- kmer logic
         if (i_write_data_ready && o_ready_to_rcv_write) begin //-- if you are recieving data
            kmer_buffer <= (kmer_buffer << BYTE) | i_write_data;

            curr_base_addr <= curr_base_addr + 1;
            if (curr_base_addr >= 15) begin
               o_kmer_ready <= 1;
            end
            if (o_kmer_ready) begin
               o_kmer_index <= o_kmer_index + 1;
            end
         end
         else begin
            o_kmer_ready <= 0;
         end // else: !if(i_write_data_ready && o_ready_to_rcv_write)
      end // else: !if(!rstn)
   end

endmodule
