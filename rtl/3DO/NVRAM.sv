module NVRAM 
#(
	parameter save_file = ""
)
(
	input          CLK,
	input          RST_N,
	
	input  [14: 0] WADDR,
	input  [ 7: 0] DI,
	input          WE,
	
	input  [14: 0] RADDR,
	output [ 7: 0] DO
);

// synopsys translate_off
`define SIM
// synopsys translate_on
	
`ifdef SIM

	reg [7:0] MEM [(32*1024)/1];
	initial begin
		MEM = '{32*1024/1{'1}};
	end
		
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			MEM = '{32*1024/1{'1}};
		end
		else begin
			if (WE) MEM[WADDR[14:0]] <= DI;
		end
	end
	
	assign DO = MEM[RADDR[14:0]];

`else
	
	

	
	
`endif

endmodule
