module OSA
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_R,
	input              CE_F,
	
	input      [ 7: 0] EDI,
	output reg [ 7: 0] EDO,
	input              ESTR_N,
	input              EWRT_N,
	input              ECMD_N,
	input              ESEL_N,
	input              ERST_N,
	output reg         ERDY_N,
	output reg         EINT_N,
	
	input      [ 7: 0] CDDI,
	output reg [ 7: 0] CDDO,
	output reg         CDEN_N,
	output reg         CDCMD_N,
	output reg         CDHWR_N,
	output reg         CDHRD_N,
	output reg         CDRST_N,
	input              CDSTEN_N,
	input              CDDTEN_N,
	input              CDMDCHG,
	
	output reg [12: 0] DBG_WAIT_CNT
);
	
	parameter int POLL_STAT_INT_EN = 0;
	parameter int POLL_READ_INT_EN = 1;
	parameter int POLL_WRIT_INT_EN = 2;
	parameter int POLL_STAT_VALID = 4;
	parameter int POLL_READ_VALID = 5;
	parameter int POLL_WRIT_VALID = 6;
	parameter int POLL_MEDIA_ACCESS = 7;
	
	
	typedef enum bit [2:0] {
		ST_IDLE,
		ST_SEL,
		ST_RDPOLL,
		ST_WRPOLL,
		ST_RDSTAT,
		ST_WRCOM,
		ST_RDDATA,
		ST_WRDATA
	} State_t;
	State_t STATE;
	
	bit  [ 7: 0] DIN;
	bit  [ 7: 0] DOUT;
	bit          RDY;
	
	bit  [ 3: 0] DEV;
	bit          ACTIVE;
	bit          EXTERN;
	bit  [ 7: 0] POLL,POLL_SPEC;
	
	bit          CD_EN;
	
	always @(posedge CLK or negedge RST_N) begin
		bit         ESTR_N_OLD,CDSTEN_N_OLD,CDDTEN_N_OLD,CDMDCHG_OLD;
		
		if (!RST_N) begin
			STATE <= ST_IDLE;
			RDY <= 0;
			DEV <= '0;
			POLL <= 8'h80;
			POLL_SPEC <= 8'h00;
			
			CD_EN <= 0;
		end
		else if (!ERST_N) begin
			STATE <= ST_IDLE;
			RDY <= 0;
			
			DEV <= '0;
			POLL <= 8'h80;//{CDMDCHG,7'h00};
			POLL_SPEC <= 8'h00;
			
			CD_EN <= 0;
		end
		else begin
			ESTR_N_OLD <= ESTR_N;
			case (STATE)
				ST_IDLE: begin
					if (!ESTR_N && ESTR_N_OLD) begin
						case ({ESEL_N,ECMD_N,EWRT_N})
							3'b000: begin STATE <= ST_WRPOLL; end
							3'b001: begin STATE <= ST_RDPOLL; end
							3'b010: begin STATE <= ST_SEL; end
							3'b011: begin  end
							3'b100: begin STATE <= ST_WRCOM; end
							3'b101: begin STATE <= ST_RDSTAT; end
							3'b110: begin STATE <= ST_WRDATA; end
							3'b111: begin STATE <= ST_RDDATA; end
						endcase
					end
				end
				
				ST_WRPOLL: begin
					if (ACTIVE) begin
						if (DEV == 4'd0 && !EXTERN) begin
							POLL[3:0] <= EDI[3:0];
							POLL[7] <= POLL[7] & ~EDI[7];
						end else if (DEV == 4'd15 && EXTERN) begin
							POLL_SPEC[3:0] <= EDI[3:0];
						end
					end
					STATE <= ST_IDLE;
				end
				
				ST_RDPOLL: begin
					if (DEV == 4'd0 && !EXTERN) begin
						DOUT <= POLL;
					end else if (DEV == 4'd15 && EXTERN) begin
						DOUT <= POLL_SPEC;
					end else begin
						DOUT <= 8'h30;
					end
					RDY <= 1;
					STATE <= ST_IDLE;
				end
				
				ST_SEL: begin
					//TODO: check device number
					DEV <= EDI[3:0];
					EXTERN <= EDI[7];
					ACTIVE <= 1;
					CD_EN <= (!EDI[7] && EDI[3:0] == 4'h0);
					STATE <= ST_IDLE;
				end
				
				ST_RDSTAT: begin
//					if (DEV == 4'd0 && !EXTERN) begin
//						case (COM0)
//							8'h82: DOUT <= ERROR_STAT[STAT_CNT];
//							8'h83: DOUT <= ID_STAT[STAT_CNT];
//							default: DOUT <= 8'hFF;
//						endcase
//						if (STAT_CNT == COM_STAT_LEN[COM0] - 1) POLL[POLL_STAT_VALID] <= 0;
//						STAT_CNT <= STAT_CNT + 1'd1;
//					end else begin
//						DOUT <= 8'hFF;
//					end
					RDY <= 1;
					STATE <= ST_IDLE;
				end
				
				ST_WRCOM: begin
//					if (DEV == 4'd0 && !EXTERN) begin
//						if (DATA_CNT == 8'd0) COM0 <= EDI;
//						DATA_CNT <= DATA_CNT + 1'd1;
//						STAT_CNT <= '0;
//						POLL[POLL_STAT_VALID] <= 1;
//					end
					STATE <= ST_IDLE;
				end
				
				ST_WRDATA: begin
					STATE <= ST_IDLE;
				end
				
				ST_RDDATA: begin
					RDY <= 1;
					STATE <= ST_IDLE;
				end
				
			endcase
			
			if (!POLL[POLL_READ_VALID] && !POLL[POLL_READ_INT_EN] && CDMDCHG && CE_R) DBG_WAIT_CNT <= DBG_WAIT_CNT + 1'd1;
			
			if (RDY && ESTR_N) RDY <= 0;
			
			CDSTEN_N_OLD <= CDSTEN_N;
			CDDTEN_N_OLD <= CDDTEN_N;
			if (!CDSTEN_N && CDSTEN_N_OLD) begin
				POLL[POLL_STAT_VALID] <= 1;
			end
			if (CDSTEN_N && !CDSTEN_N_OLD) begin
				POLL[POLL_STAT_VALID] <= 0;
			end
			
			if (!CDDTEN_N && CDDTEN_N_OLD) begin
				POLL[POLL_READ_VALID] <= 1;
				DBG_WAIT_CNT <= '0;
			end
			if (CDDTEN_N && !CDDTEN_N_OLD) begin
				POLL[POLL_READ_VALID] <= 0;
				DBG_WAIT_CNT <= '0;
			end
			
//			CDMDCHG_OLD <= CDMDCHG;
//			if (CDMDCHG && !CDMDCHG_OLD) begin
//				POLL[POLL_MEDIA_ACCESS] <= 1;
//			end
		end
	end
	assign EDO = {ESEL_N,ECMD_N,EWRT_N} ==? 3'b1?1 && DEV == 4'd0 && !EXTERN ? CDDI : DOUT;
	assign ERDY_N = ~RDY;
	assign EINT_N = ~((POLL[POLL_STAT_VALID] & POLL[POLL_STAT_INT_EN]) | (POLL[POLL_READ_VALID] & POLL[POLL_READ_INT_EN]));
	
	assign CDDO = EDI;
	assign CDCMD_N = ~(~ECMD_N);
	assign CDHWR_N = ~(ESEL_N & ~EWRT_N & ~ESTR_N);
	assign CDHRD_N = ~(ESEL_N &  EWRT_N & ~ESTR_N);
	assign CDRST_N = ERST_N;
	assign CDEN_N = ~CD_EN;
	
endmodule
