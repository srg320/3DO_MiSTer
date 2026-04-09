import P3DO_PKG::*;

module MADAM_PLAYER
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_R,
	input              CE_F,
	
	input      [31: 0] MDTI,
	output     [31: 0] MDTO,
	input BusState_t   BUS_STATE,
	input              GRANT,
	input              DMA_REG_OVF,
	output AddrGenCtl_t AG_CTL,
	
	input              PLAYXEN,
	
	input              VCE,
	input      [10: 0] H_CNT,
	input      [ 9: 0] V_CNT,
	
	output reg         PLAY_REQ,
	output reg         PLAY_INT,
	
	output reg         REF_REQ,
	
	input              PBDI,
	output             PBDO,
	output             PBCLK,
	
	output reg [ 9: 0] DBG_WAIT_CNT
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
	
	wire PLAY_ACK = (BUS_STATE_FF == PLAY_INIT0);
	
	bit          SHIFT_STROBE,SHIFT_LAST;
	bit  [ 4: 0] SHIFT_CNT;
	always @(posedge CLK or negedge RST_N) begin
		bit          ENABLE;
		bit          START_PEND,END_PEND,SHIFT_PEND;
		
		if (!RST_N) begin
			PBCLK <= 0;
			PLAY_REQ <= 0;
			PLAY_INT <= 0;
			ENABLE <= 0;
			START_PEND <= 0;
			END_PEND <= 0;
			SHIFT_PEND <= 0;
			// synopsys translate_off
			PEND <= 0;
			// synopsys translate_on
		end else begin
			if (EN && VCE) begin
				DBG_WAIT_CNT <= DBG_WAIT_CNT + 1'd1;
				
				if (V_CNT <= 10'd7) begin
					PBCLK <= 1;
					DBG_WAIT_CNT <= '0;
				end else if (V_CNT <= 10'd15) begin
					PBCLK <= 0;
					ENABLE <= PLAYXEN;
					DBG_WAIT_CNT <= '0;
				end else if (V_CNT == 10'd16 && H_CNT == 11'd0 && ENABLE) begin
					START_PEND <= 1;
				end else if (V_CNT <= 10'd239 && ENABLE) begin
					if (H_CNT == 11'd100 - 1 || H_CNT == 11'd300 - 1 || H_CNT == 11'd500 - 1 || H_CNT == 11'd700 - 1 || H_CNT == 11'd0900 - 1 || H_CNT == 11'd1100 - 1 || H_CNT == 11'd1300 - 1 || H_CNT == 11'd1500 - 1) begin
						PBCLK <= 1;
					end
					if (H_CNT == 11'd200 - 1 || H_CNT == 11'd400 - 1 || H_CNT == 11'd600 - 1 || H_CNT == 11'd800 - 1 || H_CNT == 11'd1000 - 1 || H_CNT == 11'd1200 - 1 || H_CNT == 11'd1400 - 1 || H_CNT == 11'd1559 - 1) begin
						PBCLK <= 0;
						SHIFT_PEND <= 1;
						
					end
				end else begin
					PBCLK <= 0;
					DBG_WAIT_CNT <= '0;
				end
				
				if (END_PEND) begin
					END_PEND <= 0;
					ENABLE <= 0;
				end
			end
			
			if (EN && CE_R) begin
				SHIFT_STROBE <= 0;
				if (START_PEND) begin
					SHIFT_CNT <= '0;
					SHIFT_LAST <= 0;
					PLAY_REQ <= 1;
					START_PEND <= 0;
				end
				else if (SHIFT_PEND) begin
					SHIFT_PEND <= 0;
					SHIFT_STROBE <= 1;
					SHIFT_CNT <= SHIFT_CNT + 5'd1;
					if (SHIFT_CNT == 5'd31) begin
						SHIFT_LAST <= 1;
						PLAY_REQ <= 1;
					end else begin
						SHIFT_LAST <= 0;
					end 
					DBG_WAIT_CNT <= '0;
				end
				
				if (PLAY_REQ && PLAY_ACK) begin
					PLAY_REQ <= 0;
				end
			
				PLAY_INT <= 0;
				if (DATA_WR && DMA_REG_OVF) begin
					PLAY_INT <= 1;
					END_PEND <= 1;
				end
			end
		end
	end 
	
	wire DATA_WR = (BUS_STATE_FF == PLAY_WRITE1);
	bit  [31: 0] SHF_REG;
	bit  [31: 0] BUF_OUT;
	always @(posedge CLK or negedge RST_N) begin
		bit          OUT;
		
		if (!RST_N) begin
			PBDO <= 0;
			SHF_REG <= '0;
		end
		else if (EN && CE_R) begin
			OUT <= 0;
			if (SHIFT_STROBE) begin
				{PBDO,SHF_REG} <= {SHF_REG,PBDI};
				OUT <= SHIFT_LAST;
			end
			if (OUT) begin
				BUF_OUT <= SHF_REG;
			end
		end
	end 
	
	wire REF_ACK = (BUS_STATE_FF == REF_INIT0);
	always @(posedge CLK or negedge RST_N) begin
		bit          REFRESH_PEND;
		
		if (!RST_N) begin
			REF_REQ <= 0;
			REFRESH_PEND <= 0;
		end else begin
			if (EN && VCE) begin
				if (H_CNT == 11'd0 || H_CNT == 11'd400 - 1 || H_CNT == 11'd1200 - 1) begin
					REFRESH_PEND <= 1;
				end
			end
			
			if (EN && CE_R) begin
				if (REFRESH_PEND) begin
					REF_REQ <= 1;
					REFRESH_PEND <= 0;
				end
				
				if (REF_REQ && REF_ACK) begin
					REF_REQ <= 0;
				end
			end
		end
	end 
	
	assign MDTO = BUF_OUT;
	
	always_comb begin
		AG_CTL = '0;
		
		case (BUS_STATE)
			PLAY_PREINIT1: begin
				AG_CTL.DMA_GROUP_ADDR = 7'h5C;
				AG_CTL.DMA_GROUP_ADDR_SEL = 1;
				AG_CTL.DMA_GROUP_HOLD = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h2;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			PLAY_INIT0: begin
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h2;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			PLAY_INIT1: begin
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h2;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			PLAY_READ0: begin
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h2;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			PLAY_READ1: begin
				AG_CTL.DMA_OWN_SEL = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h2;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = 3'h6;
				AG_CTL.DMA_REG_WRITE_EN = 1;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0001;
			end
			
			PLAY_PREINIT3: begin
				AG_CTL.DMA_GROUP_ADDR = 7'h5C;
				AG_CTL.DMA_GROUP_ADDR_SEL = 1;
				AG_CTL.DMA_GROUP_HOLD = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h0;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			PLAY_INIT2: begin
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h0;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			PLAY_INIT3: begin
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h1;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			PLAY_WRITE0: begin
				AG_CTL.DMA_OWN_SEL = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h0;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = 3'h5;
				AG_CTL.DMA_REG_WRITE_EN = 1;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0010;
			end
			
			PLAY_WRITE1: begin
				AG_CTL.DMA_OWN_SEL = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h1;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = 3'h4;
				AG_CTL.DMA_REG_WRITE_EN = 1;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0001;
			end
			
			REF_PREINIT1: begin
				AG_CTL.DMA_GROUP_ADDR = 7'h5C;
				AG_CTL.DMA_GROUP_ADDR_SEL = 1;
				AG_CTL.DMA_GROUP_HOLD = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h3;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			REF_INIT0: begin
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h3;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			REF_INIT1: begin
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h3;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			REF_WRITE0,
			REF_WRITE1,
			REF_WRITE2: begin
				AG_CTL.DMA_OWN_SEL = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h3;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0000;
			end
			
			REF_WRITE3: begin
				AG_CTL.DMA_OWN_SEL = 1;
				AG_CTL.DMA_REG_READ_SEL = 1;
				AG_CTL.DMA_REG_READ_CTL = 2'h3;
				AG_CTL.DMA_REG_WRITE_SEL = 0;
				AG_CTL.DMA_REG_WRITE_CTL = 3'h7;
				AG_CTL.DMA_REG_WRITE_EN = 1;
				AG_CTL.DMA_ADDR_SEL = 1;
				AG_CTL.DMA_ADDER_CTL = 4'b0111;
			end
			
			default:;
		endcase
	end

endmodule
