module ViRAL(
             clk,
             rstn,
             o_ready_to_rcv,
             i_base_ready,
             i_base,
             i_done,
             o_ready,
             o_data, //-- the output data.
             o_done
             );

   /**
    Viral usage:
    suppose you have a list of genomes [g_1, g_2, g_3, g_n] of length l each.
    You start broadcasting the genome to viral, and you will get the following result:
    --- genome 1 bcast -----||--- genome 2 bcast -----||--- genome 3 bcast -----||
    iRx: 1, 1, 1, 1, ..., 1, 1, 0, 1, 1, 1, 1, ..., 1, 1, 0, 1, 1, 1, 1, ..., 1, 1, 0
    i_d: A, C, C, G, ..., T, N, x, G, T, C, G, ..., T, N, x, A, A, G, G, ..., T, N, x,
    o_d:                          |--- encode of gen1 -----||--- encode of gen2 -----||--- encode of gen1 -----||
    */

   // Define the seed as a parameter
   parameter [4*BYTE-1:0] seed = 32'h12345678; // You can set your desired value here

   parameter  BYTE               = 8;
   parameter  Rx_rate            = 1; //-- size in bytes.
   parameter  Tx_rate            = 8; //-- size in bytes.
   parameter  KMER_SIZE          = 16; //-- in bytes.
   parameter  LOG2_FRAGMENT_SIZE = 8;
   localparam FRAGMENT_SIZE      = 2**LOG2_FRAGMENT_SIZE;
   parameter  COMPRESSION_FACTOR = 16;
   parameter  INDEX_LENGTH       = 16; //-- in bits.
   parameter  SIGNATURE_LENGTH   = 32; //-- in bits.
   parameter  BASE_COUNT         = 4;
   parameter O_DATA_CHUNK_SIZE   = 8; //-- size in bytes


   input wire                                clk;
   input wire                                rstn;
   output wire                               o_ready_to_rcv;

   input wire                                i_base_ready;
   input wire [BYTE-1:0]                     i_base;
   input wire                                i_done;

   output wire                               o_ready;
   output wire [O_DATA_CHUNK_SIZE-1:0][BYTE-1:0] o_data;
   output wire                                   o_done;


   //-- Internal wires

   //-- Double Buffer output wires
   wire [KMER_SIZE-1:0][BYTE-1:0]                db_kmer;
   wire [INDEX_LENGTH-1:0]                       db_kmer_index;
   wire                                          db_kmer_ready;
   wire                                          db_kmer_done;
   wire [FRAGMENT_SIZE-1:0][BYTE-1:0]            db_frag;
   wire                                          db_frag_ready;

   //-- Hasher output wires
   wire [4*BYTE-1:0]                             hasher_sig;

   //-- Sorter output wires
   wire                                          sorter_idxs_ready;
   wire [COMPRESSION_FACTOR-1:0][INDEX_LENGTH-1:0] sorter_idxs;

   //-- FragFetcher wires
   wire [FRAGMENT_SIZE-1:0][BYTE-1:0]              ff_final_frag;
   wire                                            ff_ready;
   wire                                            ff_frag_req;
   wire [INDEX_LENGTH-1:0]                         ff_frag_idx;
   wire                                            ff_done;

   //-- Translator wires
   wire [FRAGMENT_SIZE-1:0][BASE_COUNT-1:0][BYTE-1:0] translator_feature_vec;

   //-- Broadcaster wires
   wire                                               bcast_req;
   wire                                               bcast_chunk_done;

   //-- local buffer to connect the Sorter with FragFetcher
   reg                                                idxs_ready_buf;
   reg [COMPRESSION_FACTOR-1:0][INDEX_LENGTH-1:0]     idxs_buf;
   reg                                                ff_working;

   DoubleBuffer db(
                   .clk                  (clk),
                   .rstn                 (rstn),
                   .i_write_data_ready   (i_base_ready),
                   .i_write_data         (i_base),
                   .i_write_data_done    (i_done),
                   .o_ready_to_rcv_write (o_ready_to_rcv),
                   .o_kmer               (db_kmer), //-- the kmer value(goes into the hasher)
                   .o_kmer_index         (db_kmer_index), //-- the kmer index
                   .o_kmer_ready         (db_kmer_ready), //-- Indicates weather the kmer and kmer index are ready.
                   .o_kmer_done          (db_kmer_done), //-- Indicates weather we are done Transmitting genomic data.
                   //// Extender Pipline (aka FRAGMENT pipeline) ////
                   .i_addr               (ff_frag_idx),
                   .i_read_data_ready    (ff_frag_req),
                   .i_read_data_done     (ff_done),
                   //.o_ready_to_rcv_read(),
                   .o_frag               (db_frag),
                   .o_frag_ready         (db_frag_ready)
                   );

   Hasher hasher(
                 .seed (seed),
                 .chunk(db_kmer),
                 .hash (hasher_sig)
                 );

   Sorter sorter(
                 .clk      (clk),
                 .rstn     (rstn),
                 .en       (db_kmer_ready),
                 .i_done   (db_kmer_done),
                 .i_key    (hasher_sig),
                 .i_val    (db_kmer_index),
                 .o_ready  (sorter_idxs_ready),
                 .o_min_val(sorter_idxs)
                 );

   FragFetcher ff(
                  .clk         (clk),
                  .rstn        (rstn),
                  .i_idxs      (idxs_buf), //-- From Sorter
                  .i_idxs_ready(idxs_ready_buf && !ff_working), //-- From Sorter
                  .i_req       (bcast_req), //-- From Broadcaster
                  .o_final_frag(ff_final_frag), //-- To Broadcaster
                  .o_ready     (ff_ready), //-- To Broadcaster
                  .o_frag_req  (ff_frag_req), //-- To DB
                  .o_frag_idx  (ff_frag_idx), //-- To DB
                  .o_done      (ff_done), //-- To DB and bcaster
                  .i_frag      (db_frag), //-- From DB
                  .i_frag_ready(db_frag_ready) //--From DB
                  );


   Translator translator(
                         .i_frag       (ff_final_frag),
                         .o_feature_vec(translator_feature_vec)
                         );


   Broadcaster broadcaster(
                           .clk         (clk),
                           .rstn        (rstn),
                           .i_ready     (ff_ready), //-- if you still recieve a vaild data, should be one.
                           .i_data      (translator_feature_vec), //-- the actual data
                           .i_done      (ff_done),
                           .o_req       (bcast_req), //-- request getting data
                           .o_data      (o_data), //-- the transmitted data
                           .o_ready     (o_ready), //-- a flag containing the state of validity of the output data
                           .o_chunk_done(bcast_chunk_done),
                           .o_done      (o_done) //-- weather we are done transmitting the data, when done, this also holds as an indicator for the readyness to recieve new data.
                           );

   /*
    initial begin
    ff_working <= 0;
    idxs_ready_buf <= 0;
   end
    */

   always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
         ff_working     <= 0;
         idxs_ready_buf <= 0;
         idxs_buf       <= 'd0;
      end

      else begin
         //-- When the sorter done working we can save them
         if (sorter_idxs_ready) begin
            idxs_ready_buf <= 1;
            idxs_buf       <= sorter_idxs;
         end

         if (idxs_ready_buf && !ff_working) begin //-- If the indexes are ready, are not currently occupied, then
            ff_working     <= 1; //-- the sorter will take the job and start working
            idxs_ready_buf <= 0; //-- the indexes buffer are ready to be filled again.
         end

         if (ff_done) begin
            ff_working <= 0;
         end
      end // else: !if(!rstn)
   end // always @ (posedge clk or negedge rstn)

endmodule
