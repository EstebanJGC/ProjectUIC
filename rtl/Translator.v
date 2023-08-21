module Translator(
                  i_frag,
                  o_feature_vec
                  );

	parameter BYTE = 8;
	parameter FRAGMENT_SIZE = 256;
	parameter BASE_COUNT = 4;
	parameter BASE_A = 0; //-- change to ASCII
	parameter BASE_C = 1; //-- change to ASCII
	parameter BASE_G = 2; //-- change to ASCII
	parameter BASE_T = 3; //-- change to ASCII

	input wire [FRAGMENT_SIZE-1:0][BYTE-1:0]   	   i_frag;
	output wire [FRAGMENT_SIZE-1:0][BASE_COUNT-1:0][BYTE-1:0] o_feature_vec;

	genvar i;
	generate
	for (i = 0; i < FRAGMENT_SIZE; i = i + 1) begin : feature_vec_gen
		assign o_feature_vec[i][0] = (i_frag[i] == BASE_A) ? 8'h01 : 8'h00;
		assign o_feature_vec[i][1] = (i_frag[i] == BASE_C) ? 8'h01 : 8'h00;
		assign o_feature_vec[i][2] = (i_frag[i] == BASE_G) ? 8'h01 : 8'h00;
		assign o_feature_vec[i][3] = (i_frag[i] == BASE_T) ? 8'h01 : 8'h00;
	end
	endgenerate


endmodule
