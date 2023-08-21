// Comperator gate

module Comperator (
   clk,
   rstn,
   en,
   i_done,
   i_key,
   i_val,
   o_key,
   o_val,
   o_min_val,
   o_ready
);

parameter key_width = 32;
parameter val_width = 16;

//-- Inputs
input wire						clk;
input wire						rstn;
input wire                       en;
input wire						i_done;

input wire     [key_width-1:0]		i_key;
input wire     [val_width-1:0]		i_val;

//-- Outputs
output reg		[key_width-1:0]		o_key;
output reg		[val_width-1:0]		o_val;
output reg     [val_width-1:0]		o_min_val;
output reg							o_ready;

//-- Registers
reg				[key_width-1:0]		min_key;

//-- Wires
wire			[key_width-1:0]		new_min_key;
wire			[val_width-1:0]		new_min_val;
wire			[key_width-1:0]		new_o_key;
wire			[val_width-1:0]		new_o_val;

assign new_min_key = (i_key < min_key) ? i_key : min_key;
assign new_o_key   = (i_key < min_key) ? min_key : i_key;
assign new_min_val = (i_key < min_key) ? i_val : o_min_val;
assign new_o_val   = (i_key < min_key) ? o_min_val : i_val;


always @(posedge clk, negedge rstn) begin
   if (!rstn) begin
      min_key   <= ~0;
      o_key     <= ~0;
      o_min_val <= ~0;
      o_val     <= ~0;
      o_ready   <= 0;
   end
   else if (en == 1'b1 && !i_done) begin
      o_min_val <= new_min_val;
      o_val     <= new_o_val;
      min_key   <= new_min_key;
      o_key     <= new_o_key;
   end
   else if (i_done) begin
      o_ready <= 1;
   end
end

endmodule
