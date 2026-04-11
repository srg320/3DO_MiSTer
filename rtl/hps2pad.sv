module HPS2PAD (
	input              CLK,
	input              RST_N,
	input              CE,
	
	output reg         PBDIN,
	input              PBDOUT,
	input              PBCLK,
	
	input              EXPBDIN,
	output reg         EXPBDOUT,
	output reg         PAD_LATCH,
	
	input      [87: 0] PAD_DATA
);
	
	
	bit [ 4: 0] STATE;
	always @(posedge CLK or negedge RST_N) begin
		bit [87: 0]  DIN,DOUT;
		bit [12: 0]  WAIT_CNT;
		bit          PBCLK_OLD;
		
		if (!RST_N) begin
			STATE <= '0;
			PBDIN <= 1'b1;
			EXPBDOUT <= 1'b1;
			PAD_LATCH <= 1'b0;
		end else begin
			PAD_LATCH <= 1'b0;
			if (CE) begin
				PBCLK_OLD <= PBCLK;
				
				if (WAIT_CNT) WAIT_CNT <= WAIT_CNT - 1'd1;
				case (STATE)
					5'd0: begin
						if (PBCLK && !PBCLK_OLD) begin
							WAIT_CNT <= '1;
							STATE <= 5'd1;
						end
					end
					
					5'd1: begin
						if (WAIT_CNT == 0) begin
							WAIT_CNT <= '1;
							if (PBCLK) begin
								STATE <= 5'd2;
							end
							else begin
								STATE <= 5'd0;
							end
						end
					end
					
					5'd2: begin
						if (!PBCLK && PBCLK_OLD) begin
							WAIT_CNT <= '1;
							STATE <= 5'd3;
						end
					end
					
					5'd3: begin
						if (WAIT_CNT == 0) begin
							WAIT_CNT <= '1;
							if (!PBCLK) begin
								DOUT <= PAD_DATA;
								PAD_LATCH <= 1'b1;
								STATE <= 5'd4;
							end
							else begin
								STATE <= 5'd0;
							end
						end
					end
					
					5'd4: begin
						if (PBCLK && !PBCLK_OLD) begin 
							{EXPBDOUT,DIN} <= {DIN,PBDOUT}; 
							WAIT_CNT <= '1;
							STATE <= 5'd5; 
						end
						if (WAIT_CNT == 0) STATE <= !PBCLK ? 5'd0 : 5'd2;
					end
					
					5'd5: begin
						if (!PBCLK && PBCLK_OLD) begin 
							{PBDIN,DOUT} <= {DOUT,EXPBDIN}; 
							WAIT_CNT <= '1;
							STATE <= 5'd4; 
						end
						if (WAIT_CNT == 0) STATE <= !PBCLK ? 5'd0 : 5'd2;
					end
					
					default: ;
				endcase
			end
		end
	end
	
endmodule
