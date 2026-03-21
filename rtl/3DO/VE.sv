module VE
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              VCE_R,
	input              VCE_F,
	
	output reg         HS_R,
	output reg         HS_F,
	output reg         VS_R,
	output reg         VS_F,
	
	output             HS_N,
	output             VS_N,
	output             HBLK_N,
	output             VBLK_N,
	output             DCLK,
	
	input              DBG_BORD_DIS
);

	bit  DCLK_DIV;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DCLK_DIV <= '0;
		end
		else if (EN && VCE_R) begin
			DCLK_DIV <= ~DCLK_DIV;
		end
	end 
	wire DCE_R =  DCLK_DIV & VCE_R;
	wire DCE_F = ~DCLK_DIV & VCE_R;
	
	wire [ 9: 0] HBLANK_START = 10'd58 + 10'd16 + (DBG_BORD_DIS ? 10'd0 : 10'd8) + 10'd640;
	wire [ 9: 0] HBLANK_END = 10'd58 + 10'd16 - (DBG_BORD_DIS ? 10'd0 : 10'd8);
	
	bit  [ 9: 0] HCNT;
	bit  [ 8: 0] VCNT;
	bit          HSYNC;
	bit          VSYNC;
	bit          HBLK;
	bit          VBLK;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			HCNT <= '0;
			VCNT <= '0;
			HSYNC <= 1;
			VSYNC <= 1;
			HS_F <= 0;
			HS_R <= 0;
			VS_F <= 0;
			VS_R <= 0;
		end
		else if (EN && VCE_R) begin
			{HS_F,HS_R,VS_F,VS_R} = '0;
			if (DCLK_DIV) begin
				HCNT <= HCNT + 10'd1;
				if (HCNT == 10'd780 - 1) begin
					HCNT <= '0;
					HS_F <= 1;
					HSYNC <= 1;
					
					VCNT <= VCNT + 9'd1;
					if (VCNT == 9'd263 - 1) begin
						VCNT <= '0;
						VS_F <= 1;
						VSYNC <= 1;
					end
					if (VCNT == 9'd3 - 1) begin
						VS_R <= 1;
						VSYNC <= 0;
					end
					
					if (VCNT == 9'd21 + 9'd240 - 1) begin
						VBLK <= 1;
					end
					if (VCNT == 9'd21 - 1) begin
						VBLK <= 0;
					end
				end
				if (HCNT == 10'd58 - 1) begin
					HS_R <= 1;
					HSYNC <= 0;
				end
				
				if (HCNT == HBLANK_START - 1) begin
					HBLK <= 1;
				end
				if (HCNT == HBLANK_END - 1) begin
					HBLK <= 0;
				end
			end
		end
	end 

	assign HS_N = ~HSYNC;
	assign VS_N = ~VSYNC;
	assign HBLK_N = ~HBLK;
	assign VBLK_N = ~VBLK;
	assign DCLK = DCLK_DIV;

endmodule
