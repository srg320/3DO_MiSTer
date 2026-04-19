module P3DO_VRAM #(parameter USE_BRAM = 0) (
	input          CLK,
	input          CLK_MEM,
	input          RST_N,
	
	input  [17: 0] A,
	input  [15: 0] D,
	output [15: 0] Q,
	input          RAS_N,
	input          CAS_N,
	input  [ 1: 0] WE_N,
	input          OE_N,
	input          DSF1,
	output         RDY,
	
	input          SC,
	input          SE_N,
	output [15: 0] SQ,
	output         QSF,
	
	input  [15: 0] EQ,
	output [17: 0] ESADDR,
	output [31: 0] ESDATA,
	output         ESWR,
	output         ESRD,
	input  [31: 0] ESQ,
	input          ESTE,
	
	input  [ 3: 0] BRAM4_OFFS,
	input  [ 3: 0] BRAM2_OFFS,
	input  [ 3: 0] BRAM1_OFFS,
	
	output [ 7: 0] DBG_WAIT_CNT
);

	bit  [17: 0] A_FF;
	bit  [15: 0] D_FF;
	
	wire         USE_INT_RAM4 = (A >= ({BRAM4_OFFS+0,16'h0000}>>2) && A <= ({BRAM4_OFFS+3,16'hFFFF}>>2)) && USE_BRAM;
	wire         USE_INT_RAM2 = (A >= ({BRAM2_OFFS+0,16'h0000}>>2) && A <= ({BRAM2_OFFS+1,16'hFFFF}>>2)) && USE_BRAM;
	wire         USE_INT_RAM1 = (A >= ({BRAM1_OFFS+0,16'h0000}>>2) && A <= ({BRAM1_OFFS+0,16'hBFFF}>>2)) || (A >= (20'hFC000>>2));

	bit  [15: 0] MASK;
	bit  [15: 0] COLOR;
	
	bit  [ 8: 0] SR_WA;
	bit  [31: 0] SR_WD;
	bit          SR_WE;
	bit  [ 8: 0] SR_RA;
	bit [255: 0] SR_Q;

	bit  [ 8: 0] MEM_ROW;
	bit  [ 8: 0] MEM_COL;
	bit  [ 8: 0] SREG_POS;
	bit          RT_REQ;
	bit          RT_EXEC;	//read transfer
	bit          MWT_EXEC;	//masked write transfer
	bit          FW_EXEC;	//flash write
	bit          SIM;			//serial input mode
	bit          SOM;			//serial output mode
	bit          SPLIT;		//serial split transfer mode
	bit          ISTE;
	always @(posedge CLK_MEM or negedge RST_N) begin
		bit        RAS_N_OLD,CAS_N_OLD,SC_OLD;
		bit        RDY_OLD;
		bit        RT_PEND,MWT_PEND,FW_PEND,FW_PEND2,FW_OE_N;
		bit        FLASHWRITE,LOAD;
		
		if (!RST_N) begin
			{RT_PEND,MWT_PEND,FW_PEND,FW_PEND2} <= '0;
			RDY <= 1;
			MEM_ROW <= '0;
			MEM_COL <= '0;
			RT_REQ <= 0;
			{FLASHWRITE,LOAD} <= '0;
			{RT_EXEC,MWT_EXEC,FW_EXEC} <= '0;
			SIM <= 0;
			SOM <= 0;
			SPLIT <= 0;
			SREG_POS <= '0;
			SR_WA <= '0;
			SR_WE <= 0;
			SR_RA <= '0;
			ISTE <= 0;
		end else begin
			RT_REQ <= 0;
			
			A_FF <= A;
			D_FF <= D;
			RAS_N_OLD <= RAS_N;
			CAS_N_OLD <= CAS_N;
			RDY_OLD <= RDY;
			if ((!RAS_N && RAS_N_OLD) || (RDY && !RDY_OLD)) begin
				if (RT_EXEC || MWT_EXEC || FW_EXEC) begin
					if (!OE_N || !WE_N || DSF1 || !(USE_INT_RAM4 || USE_INT_RAM2 || USE_INT_RAM1)) RDY <= 0;
				end else if (!OE_N && WE_N) begin
					RT_PEND <= 1;
				end else if (!OE_N && !WE_N /*&& !DSF1*/) begin
					MWT_PEND <= 1;
				end else if (OE_N && !WE_N /*&& DSF1*/) begin
					FW_PEND <= 1;
				end else if (OE_N && WE_N) begin
					if (DSF1) LOAD <= 1;
				end
			end 
			else if (!RDY && !RT_EXEC && !MWT_EXEC && !FW_EXEC) begin
				RDY <= 1;
			end
			if (!CAS_N && CAS_N_OLD) begin
				FW_PEND2 <= 1;
				FW_OE_N <= OE_N;
			end
			
			if (RT_PEND) begin
				RT_PEND <= 0;
				if ({MEM_ROW,MEM_COL[8]} != A_FF[17:8] || !DSF1) begin
					{MEM_ROW,MEM_COL} <= A_FF[17:0];
					RT_EXEC <= 1;
					RT_REQ <= 1;
					SIM <= 0;
					SOM <= 1;
					SPLIT <= DSF1;
					SREG_POS <= {A_FF[8:1],1'b0};
					ISTE <= USE_INT_RAM4 | USE_INT_RAM2 | USE_INT_RAM1;
				end
				if (!DSF1) SR_RA <= A_FF[8:0];
			end else if (MWT_PEND) begin
				MWT_PEND <= 0;
				MEM_ROW <= A_FF[17:9];
//				MEM_COL <= A_FF[8:0];
				MASK <= D_FF;
				MWT_EXEC <= !SE_N;
				SIM <= 1;
				SOM <= 0;
				SPLIT <= DSF1;
				SREG_POS <= '0;
				ISTE <= USE_INT_RAM4 | USE_INT_RAM2 | USE_INT_RAM1;
			end else if (FW_PEND) begin
				FW_PEND <= 0;
				MEM_ROW <= A_FF[17:9];
//				MEM_COL <= A_FF[8:0];
				FLASHWRITE <= DSF1;
				SPLIT <= 0;
				SREG_POS <= '0;
				MASK <= D_FF;
			end
			if (FW_PEND2) begin
				FW_PEND2 <= 0;
				if (FLASHWRITE) begin
					FW_EXEC <= 1;
					ISTE <= USE_INT_RAM4 | USE_INT_RAM2 | USE_INT_RAM1;
				end
				if (FW_OE_N) begin
					if (LOAD && DSF1) COLOR <= D_FF;
					if (LOAD && !DSF1) MASK <= D_FF;
				end
				FLASHWRITE <= 0;
				LOAD <= 0;
			end
			
			SC_OLD <= SC;
			if (!SC && SC_OLD && SOM) begin
				SR_RA <= SR_RA + 9'h1;
				case (SR_RA[0])
					1'b0: SQ <= SR_DATA[31:16];
					1'b1: SQ <= SR_DATA[15: 0];
				endcase
			end
			
			if (RT_EXEC || MWT_EXEC || FW_EXEC) DBG_WAIT_CNT <= DBG_WAIT_CNT + 1'd1;
			
			SR_WE <= 0;
			if ((RT_EXEC || MWT_EXEC || FW_EXEC) && (ESTE || ISTE)) begin
				SR_WA <= SREG_POS;
				SR_WD <= ESQ;
				SR_WE <= RT_EXEC;
				
				SREG_POS <= SREG_POS + (ISTE ? 9'h10 : 9'h2);
				if (((SREG_POS[7:0] == 8'hFE && ESTE) || (SREG_POS[7:4] == 4'hF && ISTE)) && SPLIT) begin
					RT_EXEC <= 0;
					ISTE <= 0;
				end
				if (((SREG_POS[8:0] == 9'h0FE && ESTE) || (SREG_POS[8:4] == 5'h0F && ISTE)) && !SPLIT) begin
					if (RT_EXEC) RT_REQ <= 1;
				end
				if (((SREG_POS[8:0] == 9'h1FE && ESTE) || (SREG_POS[8:4] == 5'h1F && ISTE)) && !SPLIT) begin
					RT_EXEC <= 0;
					MWT_EXEC <= 0;
					FW_EXEC <= 0;
					ISTE <= 0;
				end
				
				DBG_WAIT_CNT <= '0;
			end
		end
	end
	
	bit        RAS_N_OLD,WE_N_OLD;
	always @(posedge CLK) begin
		RAS_N_OLD <= RAS_N;
		WE_N_OLD <= &WE_N;
	end
	
	wire         MEM4_SSEL = (ESADDR >= ({BRAM4_OFFS+0,16'h0000}>>2) && ESADDR <= ({BRAM4_OFFS+3,16'hFFFF}>>2)) && USE_BRAM;
	wire         MEM2_SSEL = (ESADDR >= ({BRAM2_OFFS+0,16'h0000}>>2) && ESADDR <= ({BRAM2_OFFS+1,16'hFFFF}>>2)) && USE_BRAM;
	wire         MEM1_SSEL = (ESADDR >= ({BRAM1_OFFS+0,16'h0000}>>2) && ESADDR <= ({BRAM1_OFFS+0,16'hBFFF}>>2)) || (ESADDR >= (20'hFC000>>2));
	
	wire [15: 4] MEM_SWADDR = ESADDR[15:4];
	wire[255: 0] MEM_SDATA = FW_EXEC ? {16{COLOR}} : {SR_Q[239:224],SR_Q[255:240],SR_Q[207:192],SR_Q[223:208],SR_Q[175:160],SR_Q[191:176],SR_Q[143:128],SR_Q[159:144],SR_Q[111:96],SR_Q[127:112],SR_Q[79:64],SR_Q[95:80],SR_Q[47:32],SR_Q[63:48],SR_Q[15:0],SR_Q[31:16]};//SR_Q;
	wire         MEM4_SWREN = (MWT_EXEC | FW_EXEC) & MEM4_SSEL & ISTE;
	wire         MEM2_SWREN = (MWT_EXEC | FW_EXEC) & MEM2_SSEL & ISTE;
	wire         MEM1_SWREN = (MWT_EXEC | FW_EXEC) & MEM1_SSEL & ISTE;
	
	bit  [15: 0] MEM4_Q;
	bit [255: 0] MEM4_SQ;
	VRAM_MEM #(16) mem4
	(
		.CLK(CLK),
		.ADDR(A[15:0]),
		.DATA(D),
		.WREN(~WE_N & {2{~RAS_N&~RAS_N_OLD&WE_N_OLD&USE_INT_RAM4}}),
		.Q(MEM4_Q),
		
		.SCLK(CLK_MEM),
		.SADDR(MEM_SWADDR[15:4]),
		.SDATA(MEM_SDATA),
		.SWREN(MEM4_SWREN),
		.SQ(MEM4_SQ)
	);
	
	bit  [15: 0] MEM2_Q;
	bit [255: 0] MEM2_SQ;
	VRAM_MEM #(15) mem2
	(
		.CLK(CLK),
		.ADDR(A[14:0]),
		.DATA(D),
		.WREN(~WE_N & {2{~RAS_N&~RAS_N_OLD&WE_N_OLD&USE_INT_RAM2}}),
		.Q(MEM2_Q),
		
		.SCLK(CLK_MEM),
		.SADDR(MEM_SWADDR[14:4]),
		.SDATA(MEM_SDATA),
		.SWREN(MEM2_SWREN),
		.SQ(MEM2_SQ)
	);
	
	bit  [15: 0] MEM1_Q;
	bit [255: 0] MEM1_SQ;
	VRAM_MEM #(14) mem1
	(
		.CLK(CLK),
		.ADDR(A[13:0]),
		.DATA(D),
		.WREN(~WE_N & {2{~RAS_N&~RAS_N_OLD&WE_N_OLD&USE_INT_RAM1}}),
		.Q(MEM1_Q),
		
		.SCLK(CLK_MEM),
		.SADDR(MEM_SWADDR[13:4]),
		.SDATA(MEM_SDATA),
		.SWREN(MEM1_SWREN),
		.SQ(MEM1_SQ)
	);
	assign Q = USE_INT_RAM4 ? MEM4_Q : USE_INT_RAM2 ? MEM2_Q : USE_INT_RAM1 ? MEM1_Q : EQ;

	bit          ISTE_DELAYED;
	bit          MEM4_SQ_SEL,MEM2_SQ_SEL;
	always @(posedge CLK_MEM) begin
		ISTE_DELAYED <= ISTE;
		MEM4_SQ_SEL <= MEM4_SSEL;
		MEM2_SQ_SEL <= MEM2_SSEL;
	end
	
	wire [ 8: 1] SR_RADDR = MWT_EXEC ? SREG_POS[8:1] : SR_RA[8:1];
	wire[255: 0] MEM_SQ = MEM4_SQ_SEL ? {MEM4_SQ[239:224],MEM4_SQ[255:240],MEM4_SQ[207:192],MEM4_SQ[223:208],MEM4_SQ[175:160],MEM4_SQ[191:176],MEM4_SQ[143:128],MEM4_SQ[159:144],MEM4_SQ[111:96],MEM4_SQ[127:112],MEM4_SQ[79:64],MEM4_SQ[95:80],MEM4_SQ[47:32],MEM4_SQ[63:48],MEM4_SQ[15:0],MEM4_SQ[31:16]} :
	                      MEM2_SQ_SEL ? {MEM2_SQ[239:224],MEM2_SQ[255:240],MEM2_SQ[207:192],MEM2_SQ[223:208],MEM2_SQ[175:160],MEM2_SQ[191:176],MEM2_SQ[143:128],MEM2_SQ[159:144],MEM2_SQ[111:96],MEM2_SQ[127:112],MEM2_SQ[79:64],MEM2_SQ[95:80],MEM2_SQ[47:32],MEM2_SQ[63:48],MEM2_SQ[15:0],MEM2_SQ[31:16]} :
	                                    {MEM1_SQ[239:224],MEM1_SQ[255:240],MEM1_SQ[207:192],MEM1_SQ[223:208],MEM1_SQ[175:160],MEM1_SQ[191:176],MEM1_SQ[143:128],MEM1_SQ[159:144],MEM1_SQ[111:96],MEM1_SQ[127:112],MEM1_SQ[79:64],MEM1_SQ[95:80],MEM1_SQ[47:32],MEM1_SQ[63:48],MEM1_SQ[15:0],MEM1_SQ[31:16]};
	VRAM_SHIFTREG #(9) shiftreg
	(
		.CLK(CLK_MEM),
		.WADDR(SR_WA[8:4]),
		.DATA(ISTE_DELAYED ? MEM_SQ : {8{SR_WD}}),
		.WREN(ISTE_DELAYED ? {8{SR_WE}} : {7'b0000000,SR_WE}<<SR_WA[3:1]),
		.RADDR(SR_RADDR[8:4]),
		.Q(SR_Q)
	);
	
	bit  [31: 0] SR_DATA;
	always_comb begin
		case (SR_RADDR[3:1])
			3'h0: SR_DATA = SR_Q[031:000];
			3'h1: SR_DATA = SR_Q[063:032];
			3'h2: SR_DATA = SR_Q[095:064];
			3'h3: SR_DATA = SR_Q[127:096];
			3'h4: SR_DATA = SR_Q[159:128];
			3'h5: SR_DATA = SR_Q[191:160];
			3'h6: SR_DATA = SR_Q[223:192];
			3'h7: SR_DATA = SR_Q[255:224];
		endcase
	end
	
	assign ESADDR = {MEM_ROW,SREG_POS};
	assign ESDATA = FW_EXEC ? {2{COLOR}} : SR_DATA;
	assign ESWR = (MWT_EXEC | FW_EXEC) & ~ISTE;
	assign ESRD = RT_REQ & ~ISTE;
	
	assign QSF = SR_RA[8];

endmodule
