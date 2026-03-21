import P3DO_PKG::*;

module MADAM_EXTPIF
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_R,
	input              CE_F,
	
	input              MCLK_PH1,
	input              MCLK_PH2,
	input              CPU_GRANT,
	input              CPU_RW,
	input              CPU_SEL,
	
	input      [31: 0] MDTI,
	input BusState_t   BUS_STATE,
	input              GRANT,
	input              DMA_REG_OVF,
	input              DMA_REG_ZERO,
	output AddrGenCtl_t AG_CTL,
	
	output reg         CPU_REQ,
	output reg         DMA_REQ,
	input              DMA_ACK,
	output reg [ 2: 0] NEXT,
	
	input              PLAYER_INT,
	
	output     [10: 0] H_CNT,
	output     [ 9: 0] V_CNT,
	output             FORCE_CLUT,
	
	input              VCE_R,
	input              VCE_F,
	input              DMAREQ,
	input      [ 4: 0] DMACH,//
	output reg [ 2: 0] CCODE,
	input              CREADY_N,
	input              PCSC
	
`ifdef DEBUG
	                   ,
	output reg [ 7: 0] DBG_FRAME_CNT
`endif
);

	BusState_t BUS_STATE_FF;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			BUS_STATE_FF <= BUS_IDLE;
		end
		else if (EN && CE_R) begin
			BUS_STATE_FF <= BUS_STATE;
		end
	end 
	
	wire BUS_PREINIT = (BUS_STATE_FF == EXTP_INIT0 || BUS_STATE_FF == EXTP_INIT2);
	wire BUS_INIT = (BUS_STATE_FF == EXTP_INIT1 || BUS_STATE_FF == EXTP_INIT3);
	wire BUS_PRERW = (BUS_STATE_FF == EXTP_READ0 || BUS_STATE_FF == EXTP_WRITE0);
	wire BUS_READ = (BUS_STATE_FF == EXTP_READ1);
	wire BUS_WRITE = (BUS_STATE_FF == EXTP_WRITE1);
	
	bit  [ 4: 0] DMA_CHAN;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			DMA_REQ <= 0;
		end
		else if (EN && CE_R) begin
			if (DMAREQ) begin
				DMA_CHAN <= DMACH;
				DMA_REQ <= 1;
			end
			if (DMA_REQ && DMA_ACK) begin
				DMA_REQ <= 0;
			end
		end
	end 
	wire DMA_DIR = (DMA_CHAN >= 5'h10);
	
	bit  [ 1: 0] BURST_CNT;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			BURST_CNT <= '0;
		end
		else if (EN && CE_R) begin
			if (BUS_INIT) begin
				BURST_CNT <= 2'd0;
			end
			if (BUS_READ || BUS_WRITE) begin
				BURST_CNT <= BURST_CNT + 2'd1;
			end
		end
	end 
	wire         BURST_LAST = (BURST_CNT == (DMA_CHAN == 5'h14 ? 2'd3 : 2'd2));
	
	bit          BLOCK_END,BLOCK_LAST;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			CPU_REQ <= 0;
			CCODE <= '0;
			BLOCK_END <= 0;
			BLOCK_LAST <= 0;
		end
		else if (EN && CE_R) begin
			if (BUS_WRITE || BUS_READ) begin
				BLOCK_END <= DMA_REG_OVF;
				BLOCK_LAST <= DMA_REG_ZERO;
			end
			if (BUS_STATE_FF == EXTP_INFO0) begin
				BLOCK_END <= 0;
				BLOCK_LAST <= 0;
			end
			
			if (CPU_GRANT) begin
				CCODE <= '0;
				if (CPU_SEL && !CPU_REQ) begin
					CCODE <= CPU_RW ? 3'h1 : 3'h3;
					CPU_REQ <= 1;
				end
				else if (CPU_SEL && CPU_REQ && !CREADY_N && MCLK_PH2) begin
					CPU_REQ <= 0;
				end
			end
			else if (GRANT) begin
				CCODE <= '0;
				if (BUS_PREINIT || (BUS_PRERW && !BLOCK_LAST && !BURST_LAST)) begin
					CCODE <= 3'h2;
				end
				if (BUS_STATE_FF == EXTP_LOOP3) begin
					CCODE <= 3'h7;
				end
				if (BUS_STATE_FF == EXTP_INFO0) begin
					CCODE <= BLOCK_END ?  3'h3 : 3'h2;//TODO
				end
			end
//			else if (PLAYER_INT) begin
//				CCODE <= 3'h7;
//			end
		end
	end
	
	always_comb begin
		AG_CTL = '0;
		NEXT = {2'b00,DMA_DIR};
		
		case (BUS_STATE)
			EXTP_INIT0: begin
				AG_CTL.DMA_GROUP_ADDR = {DMA_CHAN,2'h0};
				AG_CTL.DMA_GROUP_ADDR_SEL = 1;
				AG_CTL.DMA_GROUP_HOLD = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h0;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			EXTP_INIT1: begin
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h1;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			EXTP_READ0: begin
				AG_CTL.DMA_OWN_SEL = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h0;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = {DMA_CHAN[0],2'h1};
				AG_CTL.DMA_REG_WRITE_EN = 1;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0010;
			end
			
			EXTP_READ1: begin
				AG_CTL.DMA_OWN_SEL = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h1;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = {DMA_CHAN[0],2'h0};
				AG_CTL.DMA_REG_WRITE_EN = 1;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0001;
				NEXT = {2'b00,~(BURST_LAST|DMA_REG_OVF)};
			end
			
			EXTP_INIT2: begin
				AG_CTL.DMA_GROUP_ADDR = {DMA_CHAN,2'h0};
				AG_CTL.DMA_GROUP_ADDR_SEL = 1;
				AG_CTL.DMA_GROUP_HOLD = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h0;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			EXTP_INIT3: begin
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h1;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			EXTP_WRITE0: begin
				AG_CTL.DMA_OWN_SEL = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h0;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = {DMA_CHAN[0],2'h1};
				AG_CTL.DMA_REG_WRITE_EN = 1;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0010;
			end
			
			EXTP_WRITE1: begin
				AG_CTL.DMA_OWN_SEL = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h1;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = {DMA_CHAN[0],2'h0};
				AG_CTL.DMA_REG_WRITE_EN = 1;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0001;
				NEXT = {2'b00,~(BURST_LAST|DMA_REG_OVF)};
			end
			
			EXTP_LOOP0: begin
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h3;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			EXTP_LOOP1: begin
				AG_CTL.DMA_OWN_SEL = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h2;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = {DMA_CHAN[0],2'h1};
				AG_CTL.DMA_REG_WRITE_EN = BLOCK_END;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
//				NEXT = {2'b00,~(BURST_LAST|DMA_REG_OVF)};
			end
			
			EXTP_LOOP2: begin
				AG_CTL.DMA_OWN_SEL = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h3;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = {DMA_CHAN[0],2'h0};
				AG_CTL.DMA_REG_WRITE_EN = BLOCK_END;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			EXTP_LOOP3: begin
				AG_CTL.DMA_ZERO_SEL = 1;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = {DMA_CHAN[0],2'h2};
				AG_CTL.DMA_REG_WRITE_EN = 0;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
//				NEXT = {2'b00,~(BURST_LAST|DMA_REG_OVF)};
			end
			
			EXTP_INFO0: begin
				AG_CTL.DMA_ZERO_SEL = 1;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = {DMA_CHAN[0],2'h3};
				AG_CTL.DMA_REG_WRITE_EN = 0;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
//				NEXT = {2'b00,~(BURST_LAST|DMA_REG_OVF)};
			end
		
			default:;
		endcase
	end
	
	bit  [10: 0] HCOUNT;
	bit  [ 9: 0] VCOUNT;
	bit          VZ,VN,FN,FC,VR,VD,VL;
	always @(posedge CLK or negedge RST_N) begin
		bit  [ 3: 0] PCSC_OLD;
		
		if (!RST_N) begin
			HCOUNT <= '0;
			VCOUNT <= '0;
			{VZ,VN,FN,FC,VR,VD,VL} <= '0;
			PCSC_OLD <= '0;
		end
		else if (EN && VCE_R) begin
			PCSC_OLD <= {PCSC_OLD[2:0],PCSC};
			
			HCOUNT <= HCOUNT + 11'd1;
			if (PCSC_OLD == 4'b0011) begin
				HCOUNT <= '0;
				VCOUNT <= VCOUNT + 1'd1;
				if (VL) begin
					VCOUNT <= '0;
`ifdef DEBUG
					DBG_FRAME_CNT <= DBG_FRAME_CNT + 1'd1;
`endif
				end
			end
			
			case (HCOUNT)
				11'd0: VZ <= PCSC;
				11'd1: VN <= PCSC;
				11'd2: FN <= PCSC;
				11'd3: FC <= PCSC;
				11'd4: VR <= PCSC;
				11'd5: VD <= PCSC;
				11'd6: VL <= PCSC;
			endcase
		end
	end 
	assign H_CNT = HCOUNT;
	assign V_CNT = VCOUNT;
	assign FORCE_CLUT = FC;
	

endmodule
