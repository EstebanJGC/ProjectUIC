module Hasher(
   seed,
   chunk,
   hash
);

input  [31:0] seed;
input  [127:0] chunk;
output [31:0] hash;

wire [31:0] murmur_outs [4:0];

assign murmur_outs[0] = seed;
assign hash = murmur_outs[4];


genvar i;
generate
    for (i=1; i<=4; i=i+1)
   begin : murmur_blocks_generator
    murmur_4bytes heap_comps (
                              .seed (murmur_outs[i-1]),
                              .chunk(chunk[32*i-1:32*(i-1)]),
                              .hash (murmur_outs[i])
                              );
   end
endgenerate

endmodule;
