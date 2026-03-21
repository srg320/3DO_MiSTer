// synopsys translate_off
`define SIM
`define DEBUG
// synopsys translate_on

module CLIO_VIDEO
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              PAL,
	
	input              VCE_R,
	input              VCE_F,
	input              HS_N,
	input              VS_N,
	
	output     [10: 0] HCNT,
	output     [ 8: 0] VCNT,
	output             FLD,
	
	input      [31: 0] S,
	input              LSC_N,
	input              RSC_N,
	output             PCSC,
	
	output     [23: 0] AD,
	input      [ 7: 0] DBG_EXT
`ifdef DEBUG
                      ,
	output reg [15: 0] DBG_PREV_PIX,
	output reg [15: 0] DBG_CURR_PIX
`endif
);
	
	bit  [ 2: 0] HSTART;
	bit  [ 6: 0] INFO;
	always @(posedge CLK or negedge RST_N) begin
		bit          HS_N_OLD;
		bit          CHS;
		
		if (!RST_N) begin
			HSTART <= '0;
		end
		else if (EN && VCE_R) begin
			HS_N_OLD <= HS_N;
			CHS = HS_N & ~HS_N_OLD;
			
			HSTART <= {HSTART[1:0],CHS};			
			INFO <= {INFO[5:0],HSTART[2]};
		end
	end 
	
	bit  [10: 0] HCOUNT;
	bit  [ 8: 0] VCOUNT;
	bit          FIELD;
	always @(posedge CLK or negedge RST_N) begin
		bit          VS_N_OLD;
		
		if (!RST_N) begin
			HCOUNT <= '0;
			VCOUNT <= '0;
			FIELD <= 0;
			VS_N_OLD <= 1;
		end
		else if (EN && VCE_R) begin
			HCOUNT <= HCOUNT + 11'd1;
			if (HSTART[2]) begin
				HCOUNT <= '0;
				VCOUNT <= VCOUNT + 9'd1;
				if (!VS_N && VS_N_OLD) begin
					VCOUNT <= '0;
					FIELD <= ~FIELD;
				end
				VS_N_OLD <= VS_N;
			end
		end
	end 
	wire VZ = (VCOUNT == 9'd0);
	wire VN = VCOUNT[0];
	wire FN = FIELD;
	wire FC = (VCOUNT == 9'd5);
	wire VR = 0;
	wire VD = PAL;
	wire VL = (VCOUNT == 9'd262);
	assign PCSC = |HSTART | (INFO[0] & VZ) | 
	                        (INFO[1] & VN) | 
									(INFO[2] & FN) | 
									(INFO[3] & FC) |
									(INFO[4] & VR) |
									(INFO[5] & VD) |
									(INFO[6] & VL);
									
	assign HCNT = HCOUNT;
	assign VCNT = VCOUNT;
	assign FLD = FIELD;
	
	
	bit          READ_EN;
	bit          COPY_EN;
	bit          WRITE_EN;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			READ_EN <= 0;
			COPY_EN <= 0;
			WRITE_EN <= 0;
		end
		else if (EN && VCE_R) begin
			if (HSTART[2]) begin
//				WRITE_EN <= 0;
			end else begin
				if (HCOUNT == 11'd11 - 1) begin
					READ_EN <= 1;
				end
				if (HCOUNT == 11'd1293 - 1) begin
					READ_EN <= 0;
				end
				
				if (HCOUNT == 11'd1295 - 1) begin//
					COPY_EN <= 1;
				end
				if (HCOUNT == 11'd1295 + 33 - 1) begin
					COPY_EN <= 0;
				end
				
				if (HCOUNT == 11'd1340 - 1) begin
					WRITE_EN <= 1;
				end
				if (HCOUNT == 11'd1400 - 1) begin
					WRITE_EN <= 0;
				end
			end
		end
	end 
	
	
	bit          LSCAP_N;
	bit          RSCAP_N;
	bit          SCAP_SEL;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			LSCAP_N <= 0;
			RSCAP_N <= 0;
			SCAP_SEL <= 0;
		end
		else if (EN && VCE_R) begin
			LSCAP_N <= LSC_N;
			RSCAP_N <= RSC_N;
			if (!LSCAP_N)
				SCAP_SEL <= 1;
			else if (!RSCAP_N)
				SCAP_SEL <= 0;
		end
	end 
	wire CAPCLKEN_N = LSCAP_N & RSCAP_N;
	
	bit  [15: 0] LSCAP_BUF;
	bit  [15: 0] RSCAP_BUF;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			LSCAP_BUF <= '0;
			RSCAP_BUF <= '0;
		end
		else if (EN && VCE_R) begin
			if (!LSCAP_N) begin
				LSCAP_BUF <= S[31:16];
			end
			if (!RSCAP_N) begin
				RSCAP_BUF <= S[15:0];
			end
		end
	end 
	wire [31: 0] SCAP = {LSCAP_BUF,RSCAP_BUF};
	
	bit          CAPEND1_N,CAPEND2_N,CAPEND3_N,CAPEND4_N;
	bit  [ 2: 0] PIPEREAD;
	bit          READ;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			{CAPEND1_N,CAPEND2_N,CAPEND3_N,CAPEND4_N} <= '0;
			PIPEREAD <= '0;
			READ <= 0;
		end
		else if (EN && VCE_R) begin
			CAPEND1_N <= CAPCLKEN_N;
			CAPEND2_N <= CAPEND1_N;
			CAPEND3_N <= CAPEND2_N;
			CAPEND4_N <= CAPEND3_N;
			
			{READ,PIPEREAD} <= {PIPEREAD,READ_EN};
		end
	end 
	
	wire LOAD = ~LSCAP_N & ~RSCAP_N;
	bit  [ 9: 0] AMYCTL;
	DispCtrl_t   DISPCTL;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			AMYCTL <= '0;
			DISPCTL <= '0;
		end
		else if (EN && VCE_R) begin
			if (LOAD && !CAPEND1_N) begin
				if (!SCAP[30] && SCAP[31]) begin
					AMYCTL <= SCAP[9:0];
				end
				if (!SCAP[29] && SCAP[30] && SCAP[31]) begin
					DISPCTL <= SCAP[29:0];
				end
			end
		end
	end 
	
	bit  [15: 0] INPUT;
	always_comb begin
		bit  [15: 0] TEMP;
		bit          B0;
		
		case (SCAP_SEL)
			1'b1: TEMP = LSCAP_BUF;
			1'b0: TEMP = RSCAP_BUF;
		endcase
		
		case (DISPCTL.BLSB)
			2'b00: B0 = 0;
			2'b01: B0 = TEMP[5];
			2'b10: B0 = TEMP[0];
			2'b11: B0 = TEMP[0];//??
		endcase
		INPUT = {TEMP[15:1],B0};
//		LSB = TEMP[0]&DISPCTL[4];
//		MSB = TEMP[15];
	end
	
	bit          CURR_PREV;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			CURR_PREV <= 0;
		end
		else if (EN && VCE_R) begin
			if (HSTART[0]) begin
				CURR_PREV <= 0;
			end
			
			if (!CAPEND2_N) begin
				CURR_PREV <= ~CURR_PREV;
`ifdef DEBUG
				if (!CURR_PREV) DBG_PREV_PIX <= INPUT;
				if ( CURR_PREV) DBG_CURR_PIX <= INPUT;
`endif
			end
		end
	end 
	
`ifdef DEBUG
	bit          DBG_HL_DOT;
	bit  [10: 0] DBG_HCNT;
	bit  [ 9: 0] DBG_HL_HPOS;
	bit  [ 8: 0] DBG_HL_VPOS;
	always @(posedge CLK or negedge RST_N) begin
		bit  [ 7: 0] DBG_EXT_OLD;
		
		if (!RST_N) begin
			DBG_HCNT <= '0;
			DBG_HL_HPOS <= 5;
			DBG_HL_VPOS <= 5;
		end
		else if (EN && VCE_R) begin
			if (HSTART[0]) begin
				DBG_HCNT <= '0;
			end
			if (READ_EN && !CAPEND1_N) begin
				DBG_HCNT <= DBG_HCNT + 1'd1;
			end
			
			DBG_EXT_OLD <= DBG_EXT;
			if (DBG_EXT[4] && !DBG_EXT_OLD[4]) begin
				DBG_HL_HPOS <= DBG_HL_HPOS - 1'd1;
			end
			if (DBG_EXT[5] && !DBG_EXT_OLD[5]) begin
				DBG_HL_HPOS <= DBG_HL_HPOS + 1'd1;
			end
			if (DBG_EXT[6] && !DBG_EXT_OLD[6]) begin
				DBG_HL_VPOS <= DBG_HL_VPOS - 1'd1;
			end
			if (DBG_EXT[7] && !DBG_EXT_OLD[7]) begin
				DBG_HL_VPOS <= DBG_HL_VPOS + 1'd1;
			end
		end
	end 
	assign DBG_HL_DOT = DBG_HCNT[10:1] == DBG_HL_HPOS && VCOUNT == (DBG_HL_VPOS + 22);
`else
	wire DBG_HL_DOT = 0;
`endif
	
	wire         BG_DET = ~|INPUT[14:0];
	bit  [23: 0] CLUT_OUTPUT;
	CLIO_CLUT CLUT
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE_R(VCE_R),
		.CE_F(VCE_F),
		
		.INPUT(INPUT ^ {1'b0,{15{DBG_HL_DOT}}}),
		
		.SCAP(SCAP),
		.WRITE(~CAPEND1_N),
		.READCLKEN(~CAPEND2_N),
		.COPY_EN(COPY_EN),
		.WRITE_EN(WRITE_EN),
		.CURR_PREV(CURR_PREV),
//		.BG_CTL(DISPCTL[29]),
		.BG_DET(BG_DET),
		
		.OUTPUT(CLUT_OUTPUT)
	);
	
	bit  [23: 0] BYPASS_OUTPUT;
	bit          BYPASS_EN;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			BYPASS_OUTPUT <= '0;
			BYPASS_EN <= 0;
		end
		else if (EN && VCE_R) begin
			if (!CAPEND2_N) begin
				BYPASS_EN <= (DISPCTL.BYPASS && INPUT[15]) /*|| DISPCTL[12]*/;
				BYPASS_OUTPUT <= {INPUT[14:10],INPUT[14:12],INPUT[9:5],INPUT[9:7],INPUT[4:0],INPUT[4:2]};
			end
		end
	end 
	
	bit [23: 0] RGB;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			RGB <= '0;
		end
		else if (EN && VCE_R) begin
			if (!CAPEND4_N)
				RGB <= BYPASS_EN ? BYPASS_OUTPUT : CLUT_OUTPUT;
		end
	end 
	
	bit          CAPEND5_N,CAPEND6_N,CAPEND7_N;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			{CAPEND5_N,CAPEND6_N,CAPEND7_N} <= '0;
		end
		else if (EN && VCE_R) begin
			CAPEND5_N <= CAPEND4_N;
			CAPEND6_N <= CAPEND5_N;
			CAPEND7_N <= CAPEND6_N;
		end
	end 
	
	bit          CAPEN_DIV;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			CAPEN_DIV <= 0;
		end
		else if (EN && VCE_R) begin
			if (!READ_EN)
				CAPEN_DIV <= 0;
			else if (!CAPEND5_N)
				CAPEN_DIV <= ~CAPEN_DIV;
		end
	end 
	
	wire PDS_CLK1 = ~CAPEND5_N & ~CAPEN_DIV;
	wire PDS_CLK2 = ~CAPEND7_N &  CAPEN_DIV;
	bit  [23: 0] LP0,LP1,LP2,LP3;
	CLIO_24DESTACKER PDESTACKER(CLK, VCE_R, EN, PDS_CLK1, PDS_CLK2, RGB, LP0, LP1, LP2, LP3);
	
	bit  [23: 0] INTERPOL_OUT;
	CLIO_INTERPOL INTERPOL
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE_R(VCE_R),
		
		.ACLK1(1'b0),
		.ACLK2(1'b0),
		
		.LP0(LP0),
		.LP1(LP1),
		.LP2(LP2),
		.LP3(LP3),
		
		.OUT(INTERPOL_OUT)
	);
	assign AD = INTERPOL_OUT;
	

endmodule


module CLIO_24DESTACKER (
	input             CLK,
	input             CE,
	input             EN,
	
	input             CLK1,
	input             CLK2,
	
	input     [23: 0] IN,
	output    [23: 0] LP0,
	output    [23: 0] LP1,
	output    [23: 0] LP2,
	output    [23: 0] LP3
);

	reg [23:0] LATCH0,LATCH1,LATCH2,LATCH3,LATCH4;
	always @(posedge CLK) begin
		if (EN && CE) begin
			if (CLK1) begin
				LATCH4 <= IN;
			end
			
			if (CLK2) begin
				LATCH2 <= IN;
				LATCH1 <= LATCH4;
				LATCH0 <= LATCH1;
				LATCH3 <= LATCH2;
			end
		end
	end

	assign {LP0,LP1,LP2,LP3} = {LATCH0,LATCH1,LATCH2,LATCH3};

endmodule
