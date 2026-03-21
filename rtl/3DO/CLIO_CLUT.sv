module CLIO_CLUT
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_R,
	input              CE_F,
	
	input      [15: 0] INPUT,
	
	input      [31: 0] SCAP,
	input              WRITE,
	input              READCLKEN,
	input              COPY_EN,
	input              WRITE_EN,
	input              CURR_PREV,
//	input              BG_CTL,
	input              BG_DET,
	
	output     [23: 0] OUTPUT
);

	bit  [ 4: 0] ADDR;
	bit          BG_SWITCH;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			ADDR <= '0;
			BG_SWITCH <= 0;
		end
		else if (EN && CE_R) begin
			if (COPY_EN) begin
				ADDR <= ADDR + 5'd1;
				if (ADDR == 5'd31)
					BG_SWITCH <= 1;
			end
			else begin
				ADDR <= '0;
				BG_SWITCH <= 0;
			end
		end
	end 
	wire COPY = COPY_EN && !WRITE_EN;
	
	bit  [ 6: 0] RRADDR,GRADDR,BRADDR;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			RRADDR <= '0;
			GRADDR <= '0;
			BRADDR <= '0;
		end
		else if (EN && CE_R) begin
			if (READCLKEN) begin
				RRADDR <= BG_DET ? {1'b1,1'b0,{4'b0000,CURR_PREV}} : {1'b0,CURR_PREV,INPUT[14:10]};
				GRADDR <= BG_DET ? {1'b1,1'b0,{4'b0000,CURR_PREV}} : {1'b0,CURR_PREV,INPUT[9:5]};
				BRADDR <= BG_DET ? {1'b1,1'b0,{4'b0000,CURR_PREV}} : {1'b0,CURR_PREV,INPUT[4:0]};
			end
		end
	end 
	wire [ 6: 0] CRADDR = BG_SWITCH ? {1'b1,1'b0,5'b00001} : {1'b0,1'b1,ADDR};
	
	wire [ 6: 0] LWADDR = SCAP[29] ? {1'b1,1'b0,5'b00001} : {1'b0,1'b1,SCAP[28:24]};
	wire [ 6: 0] CWADDR = BG_SWITCH ? {1'b1,1'b0,5'b00000} : {1'b0,1'b0,ADDR};
	wire         RWE = (SCAP[31:29] == 3'b000 || SCAP[31:29] == 3'b011 || SCAP[31:24] == 8'hE0);
	wire         GWE = (SCAP[31:29] == 3'b000 || SCAP[31:29] == 3'b010 || SCAP[31:24] == 8'hE0);
	wire         BWE = (SCAP[31:29] == 3'b000 || SCAP[31:29] == 3'b001 || SCAP[31:24] == 8'hE0);
	
	wire [ 6: 0] COL_RGB_WADDR = COPY ? CWADDR : LWADDR;
	
	bit  [ 7: 0] COL_R_OUT;
	wire [ 7: 0] COL_R_DATA = COPY ? COL_R_OUT : SCAP[23:16];
	wire         COL_R_WE = COPY || (WRITE_EN && WRITE && RWE);
	wire [ 6: 0] COL_R_RADDR = COPY ? CRADDR : RRADDR;
	CLIO_COL_TBL COL_R
	(
		.CLK(CLK),
		.EN(EN),
		
		.WADDR(COL_RGB_WADDR),
		.DIN(COL_R_DATA),
		.WE(COL_R_WE & CE_R),
		
		.RADDR(COL_R_RADDR),
		.DOUT(COL_R_OUT)
	);
	
	bit  [ 7: 0] COL_G_OUT;
	wire [ 7: 0] COL_G_DATA = COPY ? COL_G_OUT : SCAP[15:8];
	wire         COL_G_WE = COPY || (WRITE_EN && WRITE && GWE);
	wire [ 6: 0] COL_G_RADDR = COPY ? CRADDR : GRADDR;
	CLIO_COL_TBL COL_G
	(
		.CLK(CLK),
		.EN(EN),
		
		.WADDR(COL_RGB_WADDR),
		.DIN(COL_G_DATA),
		.WE(COL_G_WE & CE_R),
		
		.RADDR(COL_G_RADDR),
		.DOUT(COL_G_OUT)
	);
	
	bit  [ 7: 0] COL_B_OUT;
	wire [ 7: 0] COL_B_DATA = COPY ? COL_B_OUT : SCAP[7:0];
	wire         COL_B_WE = COPY || (WRITE_EN && WRITE && BWE);
	wire [ 6: 0] COL_B_RADDR = COPY ? CRADDR : BRADDR;
	CLIO_COL_TBL COL_B
	(
		.CLK(CLK),
		.EN(EN),
		
		.WADDR(COL_RGB_WADDR),
		.DIN(COL_B_DATA),
		.WE(COL_B_WE & CE_R),
		
		.RADDR(COL_B_RADDR),
		.DOUT(COL_B_OUT)
	);
	
	assign OUTPUT = {COL_R_OUT,COL_G_OUT,COL_B_OUT};
	

endmodule


