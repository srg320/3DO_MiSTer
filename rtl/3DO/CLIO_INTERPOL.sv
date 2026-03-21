module CLIO_INTERPOL
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_R,
	
	input              ACLK1,
	input              ACLK2,
	
	input      [23: 0] LP0,
	input      [23: 0] LP1,
	input      [23: 0] LP2,
	input      [23: 0] LP3,
	
	output reg [23: 0] OUT
);

	reg [23:0] SUM;
	always @(posedge CLK) begin
		if (EN && CE_R) begin
			SUM <= LP3;
			OUT <= SUM;
		end
	end
		

endmodule

