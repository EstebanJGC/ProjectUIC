module Sorter(
              clk,
              rstn,
              en,
              i_done,
              i_key,
              i_val,
              o_min_val,
              o_ready
              );

   parameter width = 32; //-- SIGNATURE_LENGTH.
   parameter val_width = 16; //-- INDEX_LENGTH.
   parameter heap_size = 16; //-- COMPRESSION_FACTOR.


   input    wire              clk;
   input    wire              rstn;
   input	wire                 en;
   input    wire              i_done;

   input    wire [width-1:0]  i_key;
   input    wire [val_width-1:0] i_val;

   output   wire                 o_ready;
   output  wire [heap_size-1:0][val_width-1:0] o_min_val;

   //-- Wires
   wire [width-1:0]                            keys[heap_size:0];
   wire [val_width-1:0]                        vals[heap_size:0];
   wire                                        cell_done[heap_size:0];

   reg                                         done;

   assign keys[0] = i_key;
   assign vals[0] = i_val;
   assign cell_done[0] = i_done;
   assign o_ready = cell_done[heap_size];

   /*
    initial begin
    done <= 0;
end
    */

   always @(posedge clk or negedge rstn) begin
      if (!rstn) begin
         done <= 0;
      end
      else begin
         if (o_ready) begin
            done <= 1;
         end
         if (done) begin
            done <= 0;
         end
      end // else: !if(!rstn)
   end

   genvar i;
   generate
      for (i=1; i<=heap_size; i=i+1)
        begin : comperators_generator
           Comperator heap_comps (
                                  .clk      (clk),
                                  .rstn     (rstn && !done),
                                  .en       (en),
                                  .i_done   (cell_done[i-1]),
                                  .i_key    (keys[i-1]),
                                  .i_val    (vals[i-1]),
                                  .o_key    (keys[i]),
                                  .o_val    (vals[i]),
                                  .o_min_val(o_min_val[i-1]),
                                  .o_ready  (cell_done[i])
                                  );
        end
   endgenerate

endmodule
