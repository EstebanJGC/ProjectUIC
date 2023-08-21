module Broadcaster(
                   clk,
                   rstn,
                   i_ready, //-- if you still recieve a vaild data, should be one.
                   i_data, //-- the actual data
                   i_done,
                   o_req, //-- request getting data
                   o_data, //-- the transmitted data
                   o_ready, //-- a flag containing the state of validity of the output data
                   o_chunk_done,
                   o_done //-- weather we are done transmitting the data, when done, this also holds as an indicator for the readyness to recieve new data.
                   );

   parameter BYTE = 8;
   parameter NUM_FRAGS = 16; //-- Is equal to the COMPRESSION_FACTOR

   //-- We assume that I_DATA % O_DATA == 0
   parameter I_DATA_CHUNK_SIZE = 256*4; //-- size in bytes
   parameter O_DATA_CHUNK_SIZE = 8; //-- size in bytes --- DEBUG

   parameter INDEX_LENGTH = 16; //-- in bits.

   input wire												clk;
   input wire												rstn;

   input wire                                   i_ready;
   input wire [I_DATA_CHUNK_SIZE-1:0][BYTE-1:0] i_data;
   input wire                                   i_done;

   output wire                                  o_req;
   output wire [O_DATA_CHUNK_SIZE-1:0][BYTE-1:0] o_data;
   output wire                                   o_ready;
   output reg                                    o_chunk_done;
   output reg                                    o_done;

   //-- Internal Registers
   wire [I_DATA_CHUNK_SIZE-1:0][BYTE-1:0]        buf0_out;
   wire [I_DATA_CHUNK_SIZE-1:0][BYTE-1:0]        buf1_out;
   reg                                           writer, reader;
   reg                                           writer_pending, reader_pending;
   reg [INDEX_LENGTH-1:0]                        reader_idx_ptr; //-- pointing into the data to be broadcasted inside the buffer pointed by reader.
   reg                                           req_pending; //-- a register that helps us record if our last request has been answered
   reg                                           first_posedge_passed;
   reg                                           last_chunk;
   reg                                           delayed_ready;

   wire                                          cg_ready;
   wire                                          gclk0, gclk1;
   reg                                           cg_latch_en0, cg_latch_en1;

   /*
    initial begin
    writer <= 0;
    reader <= 0;
    writer_pending <= 0;
    reader_pending <= 1; //-- waits for data to be written.
    reader_idx_ptr <= 0; //--
    req_pending <= 0;
    first_posedge_passed <= 0;
    o_chunk_done <= 0;
    o_done = 0;
    last_chunk <= 0;
   end
    */

   assign cg_ready = i_ready | delayed_ready;

   always_latch
     if (!clk) begin
        cg_latch_en0 <= cg_ready & !writer;
        cg_latch_en1 <= cg_ready & writer;
     end

   assign gclk0 = clk & cg_latch_en0;
   assign gclk1 = clk & cg_latch_en1;

   BcastBuf buf0 (
                 .clk     (gclk0),
                 .i_ready (i_ready),
                 .i_data  (i_data),
                 .o_data  (buf0_out)
                 );

   BcastBuf buf1 (
                 .clk     (gclk1),
                 .i_ready (i_ready),
                 .i_data  (i_data),
                 .o_data  (buf1_out)
                 );

   assign o_req = !req_pending && first_posedge_passed && !writer_pending; //-- we send request if there is no request pending and the condition to send request holds (in this case, the writer is ready to write)
   assign o_ready = !reader_pending; //-- The condition of data being ready is simply that the reader(broadcaster) is working and not pending.
   genvar                                        i;
   generate
      for (i = 0; i < O_DATA_CHUNK_SIZE; i = i + 1) begin : o_data_connection
         assign o_data[i] = reader ? buf1_out[reader_idx_ptr + i] :
                            buf0_out[reader_idx_ptr + i];
      end
   endgenerate

   always @(posedge clk or negedge rstn) begin
      if(!rstn) begin
         writer               <= 0;
         reader               <= 0;
         writer_pending       <= 0;
         reader_pending       <= 1; //-- waits for data to be written.
         reader_idx_ptr       <= 0; //--
         req_pending          <= 0;
         first_posedge_passed <= 0;
         o_chunk_done         <= 0;
         o_done               <= 0;
         last_chunk           <= 0;
      end // if (!rstn)
      else begin
       delayed_ready <= i_ready;
         // COMMENTED out by Slava Yuzhaninov (Slava.Yuzhaninov@biu.ac.il) on 01-11-2022:
         // if (!first_posedge_passed && rstn) begin

         // ADDED by Slava Yuzhaninov (Slava.Yuzhaninov@biu.ac.il) on 01-11-2022:
         // NOTE: rtsn=1 is part of the else block
         if (!first_posedge_passed) begin
            first_posedge_passed <= 1;
         end
         if (o_req) begin //-- if we sent a request, then the request will be pending until we recieve an ack.
            req_pending <= 1;
         end

         if (i_ready) begin //-- when recieving an ack the request we sent is now answered, hence not pending.
            req_pending <= 0;

            //-- handling the writing process
            /*
         if (writer) begin
               buf1 <= i_data;
            end else begin
               buf0 <= i_data;
            end
         */
            writer_pending <= 1;
         end

         if (writer_pending && reader == writer) begin
            writer <= ~writer;
            writer_pending <= 0;
         end

         if (reader_pending && reader != writer) begin
            reader_pending <= 0;
         end

         if (!reader_pending) begin
            if (reader_idx_ptr >= I_DATA_CHUNK_SIZE - O_DATA_CHUNK_SIZE) begin //-- if done reading(broadcasting)
               reader         <= ~reader;
               reader_pending <= 1;
               reader_idx_ptr <= 0;
               o_chunk_done   <= 1;
            end else begin
               reader_idx_ptr <= reader_idx_ptr + O_DATA_CHUNK_SIZE;
            end
         end
         if (o_chunk_done) begin
            o_chunk_done <= 0;
         end
         if (i_done) begin
            last_chunk <= 1;
         end

         if (last_chunk && o_chunk_done) begin
            o_done <= 1;
         end

         if (o_done) begin
            writer               <= 0;
            reader               <= 0;
            writer_pending       <= 0;
            reader_pending       <= 1;
            reader_idx_ptr       <= 0;
            req_pending          <= 0;
            first_posedge_passed <= 0;
            o_chunk_done         <= 0;
            o_done               <= 0;
            last_chunk           <= 0;
         end // if (o_done)
      end // else: !if(!rstn)
   end
endmodule


module BcastBuf (
                 clk,
                 i_ready,
                 i_data,
                 o_data
                 );

   parameter I_DATA_CHUNK_SIZE = 256*4; //-- size in bytes
   parameter BYTE = 8;

   input wire clk;
   input wire i_ready;
   input wire [I_DATA_CHUNK_SIZE-1:0][BYTE-1:0] i_data;
   output reg [I_DATA_CHUNK_SIZE-1:0][BYTE-1:0] o_data;

   always @(posedge clk) begin
      if(i_ready) begin
            o_data <= i_data;
      end
   end

endmodule
