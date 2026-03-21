module P3DO_CDROM
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE,
	
	input      [ 7: 0] CDDI,
	output reg [ 7: 0] CDDO,
	input              CDEN_N,
	input              CDCMD_N,
	input              CDHWR_N,
	input              CDHRD_N,
	input              CDRST_N,
	output reg         CDSTEN_N,
	output reg         CDDTEN_N,
	output reg         CDMDCHG,
	
	input      [15: 0] CDD_DATA,
	input              CDD_WR,
	input              CDD_DTEN,
	input              CDD_DIEN,
	
	input              DISCIN,
	inout      [35: 0] EXT_BUS,
	
	
	output reg [15: 0] DBG_CRC,
	output reg [ 7: 0] DBG_CMD[4],
	output reg [11: 0] DBG_WAIT_CNT
);

	parameter bit [ 7: 0] ID_STAT[12] = '{8'h83,8'h00,8'h10,8'h00,8'h01,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};
	
	parameter bit [ 7: 0]  ERROR_NO_ERR = 8'h00;
	parameter bit [ 7: 0]  ERROR_DISC_OUT = 8'h15;
	
	bit [64: 0] cd_in;
	bit [64: 0] cd_out;
	hps_ext hps_ext
	(
		.clk_sys(CLK),
		.EXT_BUS(EXT_BUS),
		.cd_in(cd_in),
		.cd_out(cd_out)
	);
	
	bit [ 7: 0] HOST_COMM[8];
//	bit [ 7: 0] CDD_STAT[8];
//	bit         CDD_STAT_RECEIV;
	bit         CDD_COMM_SEND;
	bit         CD_IN_MSB = 0;
	always @(posedge CLK) begin
		bit         cd_out64_last = 1;
		bit [ 3: 0] WAIT_CNT = '0;
	
//		CDD_STAT_RECEIV <= 0;
		if (!RST_N) begin
//			cd_out64_last = 1;
		end else if (cd_out[64] != cd_out64_last)  begin
			cd_out64_last <= cd_out[64];
//			{CDD_STAT[7],CDD_STAT[6],CDD_STAT[5],CDD_STAT[4],CDD_STAT[3],CDD_STAT[2],CDD_STAT[1],CDD_STAT[0]} <= cd_out[63:0];
			WAIT_CNT <= '1;
		end else if (WAIT_CNT) begin
			WAIT_CNT <= WAIT_CNT - 4'd1;
//			CDD_STAT_RECEIV <= (WAIT_CNT == 4'd1);
		end
		
		if (CDD_COMM_SEND) begin
			CD_IN_MSB <= ~CD_IN_MSB;
		end
	end
	assign cd_in = {CD_IN_MSB,HOST_COMM[7],HOST_COMM[6],HOST_COMM[5],HOST_COMM[4],HOST_COMM[3],HOST_COMM[2],HOST_COMM[1],HOST_COMM[0]};
	
	bit  [10: 0] CDD_DATA_ADDR;
	bit          CDD_BLOCK_READY;
	bit          CDD_IS_LOADED;
	always @(posedge CLK) begin
		bit         CDD_DTEN_OLD,CDD_DIEN_OLD;
		
		CDD_IS_LOADED <= 0;
		CDD_BLOCK_READY <= 0;
		if (CDD_WR) begin
			CDD_DATA_ADDR <= CDD_DATA_ADDR + 11'd1;
			if (CDD_DTEN && CDD_DATA_ADDR == 11'h3FF) begin
				CDD_BLOCK_READY <= 1;
			end
			if (CDD_DTEN && CDD_DATA_ADDR == 11'h400) begin
				DBG_CRC <= CDD_DATA;
				CDD_DATA_ADDR <= '0;
			end
			if (CDD_DIEN && CDD_DATA_ADDR == 11'h3FF) CDD_IS_LOADED <= 1;
		end
		
		CDD_DTEN_OLD <= CDD_DTEN;
		CDD_DIEN_OLD <= CDD_DIEN;
		if ((CDD_DTEN && !CDD_DTEN_OLD) || (CDD_DIEN && !CDD_DIEN_OLD)) begin
			CDD_DATA_ADDR <= '0;
		end
	end
		
	bit  [10: 0] DISC_TOC_RPOS;
	bit  [ 7: 0] DISC_TOC_Q;
	dpram_dif #(10,16,11,8) disc_toc 
	(
		.clock(CLK),
		
		.address_a(CDD_DATA_ADDR[9:0]),
		.data_a(CDD_DATA),
		.wren_a(CDD_DIEN & CDD_WR),
		
		.address_b(DISC_TOC_RPOS),
		.q_b(DISC_TOC_Q)
	);
	
	bit  [10: 0] DISC_DATA_RPOS;
	bit  [ 7: 0] DISC_DATA_Q;
	dpram_dif #(10,16,11,8) disc_data 
	(
		.clock(CLK),
		
		.address_a(CDD_DATA_ADDR[9:0]),
		.data_a(CDD_DATA),
		.wren_a(CDD_DTEN & ~CDD_DATA_ADDR[10] & CDD_WR),
		
		.address_b(DISC_DATA_RPOS),
		.q_b(DISC_DATA_Q)
	);
	
	typedef enum bit [2:0] {
		IO_IDLE,
		IO_CMD_READ,
		IO_CMD_WRITE,
		IO_DAT_READ
	} IOState_t;
	IOState_t IO_ST;
	
	
	typedef enum bit [2:0] {
		CMD_IDLE,
		CMD_EXEC
	} CommandState_t;
	CommandState_t CMD_ST;
	
	bit  [ 7: 0] STATUS;
	bit  [ 7: 0] ERROR;
	bit  [ 7: 0] SPEED;
	
	bit  [ 7: 0] COMMAND[8];
	wire [ 7: 0] CMD_CODE = COMMAND[0];
	bit  [ 7: 0] STAT_DATA[12];
	bit  [ 7: 0] DOUT;
	
	bit          ST_EN,DT_EN;
	
	bit  [ 3: 0] STAT_FIFO_WPOS,STAT_FIFO_RPOS;
	
	always @(posedge CLK or negedge RST_N) begin
		bit         CDHRD_N_OLD,CDHWR_N_OLD;
		bit [ 2: 0] CMD_DATA_CNT,COM_DATA_LEN;
		bit [ 3: 0] COM_STAT_CNT,COM_STAT_LEN;
		bit [10: 0] DATA_CNT;
		bit [15: 0] FRAME_CNT,NEXT_FRAME_CNT;
		bit [ 7: 0] ST_DELAY_CNT;
		bit         CMD_REC;
		
		if (!RST_N) begin
			IO_ST <= IO_IDLE;
			COMMAND <= '{8{'0}};
			STATUS <= 8'h01;
			ERROR <= ERROR_NO_ERR;
			
			CMD_DATA_CNT <= '0;
			COM_STAT_CNT <= '0;
			DATA_CNT <= '0;
			ST_EN <= 0;
			DT_EN <= 0;
			CDMDCHG <= 0;
			ST_DELAY_CNT <= '1;
			
			CMD_ST <= CMD_IDLE;
			CMD_REC <= 0;
			
			DBG_CMD <= '{4{'0}};
		end
		else if (!CDRST_N) begin
			IO_ST <= IO_IDLE;
			COMMAND <= '{8{'0}};
			STATUS <= 8'h01;
			ERROR <= ERROR_NO_ERR;
			
			CMD_DATA_CNT <= '0;
			COM_STAT_CNT <= '0;
			DATA_CNT <= '0;
			ST_EN <= 0;
			DT_EN <= 0;
			CDMDCHG <= 0;
			
			CMD_ST <= CMD_IDLE;
			CMD_REC <= 0;
		end
		else begin
			if (DT_EN && !ST_EN && CE) DBG_WAIT_CNT <= DBG_WAIT_CNT + 1'd1;
			
			STATUS[7] <= DISCIN;
			STATUS[6] <= DISCIN;
			
			NEXT_FRAME_CNT = FRAME_CNT + 16'd1;
			
			CDD_COMM_SEND <= 0;
			
			CDHRD_N_OLD <= CDHRD_N;
			CDHWR_N_OLD <= CDHWR_N;
			case (IO_ST)
				IO_IDLE: begin
					if (!CDHRD_N && CDHRD_N_OLD && !CDCMD_N && !CDEN_N) begin
						IO_ST <= IO_CMD_READ;
					end
					if (!CDHWR_N && CDHWR_N_OLD && !CDCMD_N && !CDEN_N) begin
						IO_ST <= IO_CMD_WRITE;
					end
					if (!CDHRD_N && CDHRD_N_OLD && CDCMD_N && !CDEN_N) begin
						IO_ST <= IO_DAT_READ;
					end
				end
				
				IO_CMD_READ: begin
					DOUT <= STAT_DATA[STAT_FIFO_RPOS];
					STAT_FIFO_RPOS <= STAT_FIFO_RPOS + 4'd1;
					
					COM_STAT_CNT <= COM_STAT_CNT + 4'd1;
					if (COM_STAT_CNT == COM_STAT_LEN) begin
						ST_EN <= 0;
					end
					IO_ST <= IO_IDLE;
				end
				
				IO_CMD_WRITE: begin
					CMD_DATA_CNT <= CMD_DATA_CNT + 3'd1;
					if (CMD_DATA_CNT == 0) begin
						COMMAND[0] <= CDDI;
						case (CDDI)
							8'h01: COM_DATA_LEN <= 3'd7;
							8'h04,
							8'h05,
							8'h08,
							8'h0B: COM_DATA_LEN <= 3'd0;
							default: COM_DATA_LEN <= 3'd6;
						endcase
						case (CDDI)
							8'h80: COM_STAT_LEN <= 4'd3;
							8'h82: COM_STAT_LEN <= 4'd9;
							8'h83: COM_STAT_LEN <= 4'd11;
							8'h84: COM_STAT_LEN <= 4'd6;
							8'h85: COM_STAT_LEN <= 4'd5;
							8'h86: COM_STAT_LEN <= 4'd5;
							8'h88: COM_STAT_LEN <= 4'd7;
							8'h8B: COM_STAT_LEN <= 4'd7;
							8'h8C: COM_STAT_LEN <= 4'd9;
							8'h8D: COM_STAT_LEN <= 4'd7;
							default: COM_STAT_LEN <= 4'd1;
						endcase
						DBG_CMD[0] <= COMMAND[0];
						DBG_CMD[1] <= DBG_CMD[0];
						DBG_CMD[2] <= DBG_CMD[1];
						DBG_CMD[3] <= DBG_CMD[2];
						
					end else begin
						COMMAND[CMD_DATA_CNT] <= CDDI;
						if (CMD_DATA_CNT == COM_DATA_LEN) begin
							CMD_DATA_CNT <= '0;
							COM_STAT_CNT <= '0;
							STAT_FIFO_RPOS <= '0;
							DISC_DATA_RPOS <= '0;
							if (CMD_CODE == 8'h10) begin
								DATA_CNT <= '0;
								FRAME_CNT <= '0;
							end
							CMD_REC <= 1;
						end
					end
					IO_ST <= IO_IDLE;
				end
				
				IO_DAT_READ: begin
					DOUT <= DISC_DATA_Q;
					DISC_DATA_RPOS <= DISC_DATA_RPOS + 1'd1;
					
					DATA_CNT <= DATA_CNT + 1'd1;
					if (DATA_CNT == 11'h7FF) begin
						DT_EN <= 0;
						FRAME_CNT <= NEXT_FRAME_CNT;
						if (NEXT_FRAME_CNT != {COMMAND[5],COMMAND[6]}) begin
							{HOST_COMM[0],HOST_COMM[1],HOST_COMM[2],HOST_COMM[3],HOST_COMM[4],HOST_COMM[5],HOST_COMM[6]} <= {8'h20,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};
							CDD_COMM_SEND <= 1;
						end
					end
					IO_ST <= IO_IDLE;
					
					DBG_WAIT_CNT <= '0;
				end
				
			endcase
			
			case (CMD_ST)
				CMD_IDLE: if (CMD_REC && CE) begin
					case (CMD_CODE)
						8'h02: begin	//Spin up
							if (STATUS[7] && STATUS[6]) begin STATUS[5] <= 1; STATUS[0] <= 1; ERROR <= ERROR_NO_ERR; end
							else begin STATUS[4] <= 1; STATUS[0] <= 0; ERROR <= ERROR_DISC_OUT; end
							CMD_ST <= CMD_EXEC;
						end
						
						8'h09: begin
							if (COMMAND[1] == 8'h03) begin //Set speed
								SPEED <= COMMAND[3];
							end
							else if (COMMAND[1] == 8'h05) begin //Set volume
								
							end
							CMD_ST <= CMD_EXEC;
						end
						
						8'h10: begin //Read data
							{HOST_COMM[0],HOST_COMM[1],HOST_COMM[2],HOST_COMM[3],HOST_COMM[4],HOST_COMM[5],HOST_COMM[6]} <= {COMMAND[0],COMMAND[1],COMMAND[2],COMMAND[3],COMMAND[4],COMMAND[5],COMMAND[6]};
							CDD_COMM_SEND <= 1;
							CMD_ST <= CMD_EXEC;
						end
						
						8'h80: begin	//Data path check
							CMD_ST <= CMD_EXEC;
						end
						
						8'h82: begin	//Read error
							CMD_ST <= CMD_EXEC;
						end
						
						8'h83: begin	//Read ID
							CMD_ST <= CMD_EXEC;
						end
						
						8'h85: begin	//Read capacity
							DISC_TOC_RPOS <= 10'h002;
							CMD_ST <= CMD_EXEC;
						end
						
						8'h8B: begin	//Read disc info
							DISC_TOC_RPOS <= 10'h000;
							CMD_ST <= CMD_EXEC;
						end
						
						8'h8C: begin	//Read TOC
							DISC_TOC_RPOS <= {COMMAND[2][6:0],4'h0};
							CMD_ST <= CMD_EXEC;
						end
						
						8'h8D: begin	//Read session info
							CMD_ST <= CMD_EXEC;
						end
						
						default: begin //undefined
							{HOST_COMM[6],HOST_COMM[5],HOST_COMM[4],HOST_COMM[3],HOST_COMM[2],HOST_COMM[1],HOST_COMM[0]} <= {COMMAND[6],COMMAND[5],COMMAND[4],COMMAND[3],COMMAND[2],COMMAND[1],COMMAND[0]};
							CDD_COMM_SEND <= 1;
						end
					endcase
					STAT_FIFO_WPOS <= '0;
				end
				
				CMD_EXEC: if (CE) begin
					case (COMMAND[0])
						8'h02: begin	//Spin up
							STAT_FIFO_WPOS <= STAT_FIFO_WPOS + 4'd1;
							if (STAT_FIFO_WPOS == 4'd0) begin
								STAT_DATA[0] <= 8'h02;
							end else if (STAT_FIFO_WPOS == 4'd1) begin
								STAT_DATA[1] <= STATUS;
								ERROR <= ERROR_NO_ERR;
								ST_EN <= 1;
								CMD_REC <= 0;
								CMD_ST <= CMD_IDLE;
							end
						end
						
						8'h09: begin
							STAT_FIFO_WPOS <= STAT_FIFO_WPOS + 4'd1;
							if (STAT_FIFO_WPOS == 4'd0) begin
								STAT_DATA[0] <= 8'h09;
							end else if (STAT_FIFO_WPOS == 4'd1) begin
								STAT_DATA[1] <= STATUS;
								ERROR <= ERROR_NO_ERR;
								ST_EN <= 1;
								CMD_REC <= 0;
								CMD_ST <= CMD_IDLE;
							end
						end
						
						8'h10: begin //Read data
							STAT_FIFO_WPOS <= STAT_FIFO_WPOS + 4'd1;
							if (STAT_FIFO_WPOS == 4'd0) begin
								STAT_DATA[0] <= 8'h10;
							end else if (STAT_FIFO_WPOS == 4'd1) begin
								STAT_DATA[1] <= STATUS;
								ERROR <= ERROR_NO_ERR;
//								ST_EN <= 1;
								CMD_REC <= 0;
								CMD_ST <= CMD_IDLE;
							end
						end
						
						8'h80: begin	//Data path check
							STAT_FIFO_WPOS <= STAT_FIFO_WPOS + 4'd1;
							if (STAT_FIFO_WPOS == 4'd0) begin
								STAT_DATA[0] <= 8'h80;
							end else if (STAT_FIFO_WPOS == 4'd1) begin
								STAT_DATA[1] <= 8'hAA;
							end else if (STAT_FIFO_WPOS == 4'd2) begin
								STAT_DATA[2] <= 8'h55;
							end else if (STAT_FIFO_WPOS == 4'd3) begin
								STAT_DATA[3] <= STATUS;
								ERROR <= ERROR_NO_ERR;
								ST_EN <= 1;
								CMD_REC <= 0;
								CMD_ST <= CMD_IDLE;
							end
						end
						
						8'h82: begin	//Read error
							STAT_FIFO_WPOS <= STAT_FIFO_WPOS + 4'd1;
							if (STAT_FIFO_WPOS == 4'd0) begin
								STAT_DATA[0] <= 8'h82;
							end else if (STAT_FIFO_WPOS <= 4'd8) begin
								STAT_DATA[STAT_FIFO_WPOS] <= ERROR;
							end else if (STAT_FIFO_WPOS == 4'd9) begin
								STAT_DATA[9] <= STATUS;
								ERROR <= ERROR_NO_ERR;
								ST_EN <= 1;
								CMD_REC <= 0;
								CMD_ST <= CMD_IDLE;
							end
						end
						
						8'h83: begin	//Read ID
							STAT_FIFO_WPOS <= STAT_FIFO_WPOS + 4'd1;
							STAT_DATA[STAT_FIFO_WPOS] <= ID_STAT[STAT_FIFO_WPOS];
							if (STAT_FIFO_WPOS == 4'd11) begin
								STAT_DATA[11] <= STATUS;
								ERROR <= ERROR_NO_ERR;
								ST_EN <= 1;
								CMD_REC <= 0;
								CMD_ST <= CMD_IDLE;
							end
						end
						
						8'h85: begin	//Read capacity
							DISC_TOC_RPOS <= DISC_TOC_RPOS + 10'd1;
							STAT_FIFO_WPOS <= STAT_FIFO_WPOS + 4'd1;
							if (STAT_FIFO_WPOS == 4'd0) begin
								STAT_DATA[0] <= 8'h85;
							end else if (STAT_FIFO_WPOS == 4'd1) begin
								STAT_DATA[STAT_FIFO_WPOS] <= 8'h00;
							end else if (STAT_FIFO_WPOS <= 4'd4) begin
								STAT_DATA[STAT_FIFO_WPOS] <= DISC_TOC_Q;
							end else if (STAT_FIFO_WPOS == 4'd5) begin
								STAT_DATA[5] <= STATUS;
								ERROR <= ERROR_NO_ERR;
								ST_EN <= 1;
								CMD_REC <= 0;
								CMD_ST <= CMD_IDLE;
							end
						end
							
						8'h8B: begin	//Read disc info
							DISC_TOC_RPOS <= DISC_TOC_RPOS + 10'd1;
							STAT_FIFO_WPOS <= STAT_FIFO_WPOS + 4'd1;
							if (STAT_FIFO_WPOS == 4'd0) begin
								STAT_DATA[0] <= 8'h8B;
							end else if (STAT_FIFO_WPOS <= 4'd6) begin
								STAT_DATA[STAT_FIFO_WPOS] <= DISC_TOC_Q;
							end else if (STAT_FIFO_WPOS == 4'd7) begin
								STAT_DATA[7] <= STATUS;
								ERROR <= ERROR_NO_ERR;
								ST_EN <= 1;
								CMD_REC <= 0;
								CMD_ST <= CMD_IDLE;
							end
						end
							
						8'h8C: begin	//Read TOC
							DISC_TOC_RPOS <= DISC_TOC_RPOS + 10'd1;
							STAT_FIFO_WPOS <= STAT_FIFO_WPOS + 4'd1;
							if (STAT_FIFO_WPOS == 4'd0) begin
								STAT_DATA[0] <= 8'h8C;
							end else if (STAT_FIFO_WPOS <= 4'd8) begin
								STAT_DATA[STAT_FIFO_WPOS] <= DISC_TOC_Q;
							end else if (STAT_FIFO_WPOS == 4'd9) begin
								STAT_DATA[9] <= STATUS;
								ERROR <= ERROR_NO_ERR;
								ST_EN <= 1;
								CMD_REC <= 0;
								CMD_ST <= CMD_IDLE;
							end
						end
							
						8'h8D: begin	//Read session info
							STAT_FIFO_WPOS <= STAT_FIFO_WPOS + 4'd1;
							if (STAT_FIFO_WPOS == 4'd0) begin
								STAT_DATA[0] <= 8'h8D;
							end else if (STAT_FIFO_WPOS <= 4'd6) begin
								STAT_DATA[STAT_FIFO_WPOS] <= 8'h00;
							end else if (STAT_FIFO_WPOS == 4'd7) begin
								STAT_DATA[7] <= STATUS;
								ERROR <= ERROR_NO_ERR;
								ST_EN <= 1;
								CMD_REC <= 0;
								CMD_ST <= CMD_IDLE;
							end
						end
					endcase
				end
				
			endcase
			
			if (CDD_BLOCK_READY) begin
				DT_EN <= 1;
				if (NEXT_FRAME_CNT == {COMMAND[5],COMMAND[6]}) begin
					ST_DELAY_CNT <= 8'd192;
				end
			end
			
			if (CE) begin
				if (ST_DELAY_CNT != 8'd255) begin
					ST_DELAY_CNT <= ST_DELAY_CNT - 8'd1;
				end
				if (ST_DELAY_CNT == 8'd0) begin
					ST_EN <= 1;
				end
			end
			
			if (CDD_IS_LOADED) begin
				CDMDCHG <= 1;
			end
			
		end
	end
	
	assign CDDO = DOUT;
	assign CDSTEN_N = ~ST_EN;
	assign CDDTEN_N = ~DT_EN;
//	assign CDMDCHG = 1;
	
endmodule
