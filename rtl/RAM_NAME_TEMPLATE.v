module RAM_NAME_TEMPLATE (
            CLK,
			CEB,
			WEB,
            A, D,
            BWEB,
            RTSEL,
            WTSEL,
            Q);

localparam DW          = 256 ; //-- Data width (256 bit)
localparam AW          = 7 ; //-- Adress width (128 addresses - fragments)


//=== IO Ports ===//

// Normal Mode Input
input CLK;
input CEB;
input WEB;
input [AW-1:0] A;
input [DW-1:0] D;
input [DW-1:0] BWEB;


// Data Output
output [DW-1:0] Q;


// Test Mode
input [1:0] RTSEL;
input [1:0] WTSEL;

localparam numWord = (1 << AW);

reg [DW-1:0] Q;
reg [DW-1:0] MEMORY[numWord-1:0];

integer i;

// Memory write logic
always @(posedge CLK) begin
   if (~CEB & ~WEB)
      for (i = 0; i < DW; i = i + 1) begin
             MEMORY[A][i] <= BWEB[i] ? MEMORY[A][i] : D[i];
      end
end

// Read logic
always @(posedge CLK) begin
   if (~CEB & WEB)
      Q <= MEMORY[A];
end      

task preloadData;
input [256*8:1] infile;  // Max 256 character File Name
begin
    $display("Preloading data from file %s", infile);

    $readmemh(infile, MEMORY);
end
endtask



endmodule