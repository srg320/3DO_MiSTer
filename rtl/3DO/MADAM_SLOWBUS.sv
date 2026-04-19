import P3DO_PKG::*;

module MADAM_SLOWBUS
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_R,
	input              CE_F,
	
	input      [31:16] ADDR,
	input              WR,
	input              SEL,
	input      [31: 0] MDTI,
	output     [31: 0] MDTO,
	
	input      [31: 0] PDI,
	output reg [ 7: 0] PDO,
	output             ROMCS_N,
	output             SRAMW_N,
	output             SRAMR_N
);

	wire SRAM_SEL = (SEL && ADDR[20] && ADDR[19:18] == 2'b01);
	wire ROM_SEL = (SEL && !ADDR[20]);
	
	always @(posedge CLK) begin
		PDO <= MDTI[7:0];
	end
	assign ROMCS_N = ~ROM_SEL;
	assign SRAMW_N = ~(SRAM_SEL &&  WR);
	assign SRAMR_N = ~(SRAM_SEL && ~WR);
	
	assign MDTO = PDI;

endmodule
