module sdram
(
	inout  reg [15: 0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [12: 0] SDRAM_A,    // 13 bit multiplexed address bus
	output reg         SDRAM_DQML, // byte mask
	output reg         SDRAM_DQMH, // byte mask
	output reg [ 1: 0] SDRAM_BA,   // two banks
	output             SDRAM_nCS,  // a single chip select
	output reg         SDRAM_nWE,  // write enable
	output reg         SDRAM_nRAS, // row address select
	output reg         SDRAM_nCAS, // columns address select
	output             SDRAM_CLK,
	output             SDRAM_CKE,

	// cpu/chipset interface
	input              init,			// init signal after FPGA config to initialize RAM
	input              clk,			// sdram is accessed at up to 128MHz
	input              sync,			//

	input      [22: 2] laddr,
	input      [ 1: 0] lwe,
	input              lras,
	input      [ 3: 0] lcode,
	input      [22: 2] raddr,
	input      [ 1: 0] rwe,
	input              rras,
	input      [ 3: 0] rcode,
	
	input      [31: 0] din,
	output     [31: 0] dout,
	
	input              rfs

`ifdef DEBUG
	                   ,
	output [1:0] dbg_ctrl_bank,
	output [1:0] dbg_ctrl_cmd,
	output       dbg_ctrl_we,
	output       dbg_ctrl_rfs,
	
	output       dbg_data_read,
	output       dbg_out_read,
	output       dbg_out_bank,
	
	output reg [15: 0] dbg_sdram_d,
	
	output reg [31: 0] dbg_no_refresh,
	output reg [23:0] dbg_numrfs_in_64ms,
	
	output reg [21:11] dbg_open_lpage,dbg_open_rpage,
	output reg         dbg_cross_page
`endif
);

	localparam RASCAS_DELAY   = 3'd2; // tRCD=20ns -> 2 cycles
	localparam BURST          = 3'd0; // 0=1, 1=2, 2=4, 3=8, 7=full page
	localparam ACCESS_TYPE    = 1'd0; // 0=sequential, 1=interleaved
	localparam CAS_LATENCY    = 3'd2; // 2/3 allowed
	localparam OP_MODE        = 2'd0; // only 0 (standard operation) allowed
	localparam NO_WRITE_BURST = 1'd1; // 0=write burst enabled, 1=only single access write

	localparam bit [12:0] MODE = {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST}; 
	
	localparam STATE_IDLE  = 3'd0;             // state to check the requests
	localparam STATE_START = STATE_IDLE+1'd1;  // state in which a new command is started
	localparam STATE_CONT  = STATE_START+RASCAS_DELAY;
	localparam STATE_READY = STATE_CONT+CAS_LATENCY+1'd1;
	localparam STATE_LAST  = STATE_READY;      // last state in cycle
	
	localparam MODE_NORMAL = 2'b00;
	localparam MODE_RESET  = 2'b01;
	localparam MODE_LDM    = 2'b10;
	localparam MODE_PRE    = 2'b11;

	// initialization 
	reg [2:0] init_state = '0;
	reg [1:0] mode;
	reg       init_done = 0;
	always @(posedge clk) begin
		reg [4:0] reset = 5'h1f;
		reg init_old = 0;
		
		if(mode != MODE_NORMAL || init_state != STATE_IDLE || reset) begin
			init_state <= init_state + 1'd1;
			if (init_state == STATE_LAST) init_state <= STATE_IDLE;
		end

		init_old <= init;
		if (init_old & ~init) begin
			reset <= 5'h1f; 
			init_done <= 0;
		end
		else if (init_state == STATE_LAST) begin
			if(reset != 0) begin
				reset <= reset - 5'd1;
				if (reset == 15 || reset == 14) begin mode <= MODE_PRE; end
				else if(reset == 4 || reset == 3) begin mode <= MODE_LDM; end
				else                mode <= MODE_RESET;
			end
			else begin
				mode <= MODE_NORMAL;
				init_done <= 1;
			end
		end
	end
	
	localparam CTRL_IDLE = 2'd0;
	localparam CTRL_RAS = 2'd1;
	localparam CTRL_CAS = 2'd2;
	localparam CTRL_PRE = 2'd3;
	
	typedef struct packed
	{
		bit [ 1:0] CMD;	//command
		bit [ 1:0] BANK;	//bank
		bit [22:1] ADDR;	//read/write address
		bit [15:0] DATA;	//write data
		bit        RD;		//read	
		bit        WE;		//write enable
		bit [ 1:0] BE;		//write byte enable
		bit        RFS;	//refresh	
	} state_t;
	state_t state[6];
	reg [ 3: 0] st_num;
	
	reg ras_old,rfs_old;
	always @(posedge clk) begin
		reg sync_old;
		
		sync_old <= sync;
		if (!init_done) begin
			st_num <= 4'd8;
		end else begin
			if (st_num < 4'd8) st_num <= st_num + 4'd1;
			
			if (sync && !sync_old) begin
				st_num <= 4'd1;
			end
			
//			ras_old <= ras;
			rfs_old <= rfs;
		end
	end
	
	always @(posedge clk) begin
		reg lpage_opened = 0,rpage_opened = 0;
		
`ifdef DEBUG
		dbg_no_refresh <= dbg_no_refresh + 1'd1;
`endif
		
		state[0] <= '0;
		if (!init_done) begin
			state[0].CMD <= init_state == STATE_START ? CTRL_RAS : 
			                init_state == STATE_CONT  ? CTRL_CAS : 
								                             CTRL_IDLE;
			state[0].RFS <= 1;
		end else begin
			if (lras && lcode == 4'h8 && st_num[2:0] == 3'd5) begin
				state[0].CMD  <= CTRL_RAS;
				state[0].ADDR <= {laddr,1'b0};
				state[0].BANK <= 2'd0;
				lpage_opened <= 1;
`ifdef DEBUG
				dbg_cross_page <= 0;
				dbg_open_lpage <= laddr[21:11];
`endif
			end
			if (rras && rcode == 4'h8 && st_num[2:0] == 3'd6) begin
				state[0].CMD  <= CTRL_RAS;
				state[0].ADDR <= {raddr,1'b0};
				state[0].BANK <= 2'd1;
				rpage_opened <= 1;
`ifdef DEBUG
				dbg_cross_page <= 0;
				dbg_open_rpage <= raddr[21:11];
`endif
			end
			
			if (lras && lcode == 4'h1 && st_num[2:0] == 3'd0 && lpage_opened) begin
				state[0].CMD  <= CTRL_CAS;
				state[0].ADDR <= {laddr,1'b0};
				state[0].RD   <= 1;
				state[0].BANK <= 2'd0;
`ifdef DEBUG
				dbg_cross_page <= (dbg_open_lpage != laddr[21:11]);
`endif
			end
			if (rras && rcode == 4'h1 && st_num[2:0] == 3'd1 && rpage_opened) begin
				state[0].CMD  <= CTRL_CAS;
				state[0].ADDR <= {raddr,1'b0};
				state[0].RD   <= 1;
				state[0].BANK <= 2'd1;
`ifdef DEBUG
				dbg_cross_page <= (dbg_open_rpage != raddr[21:11]);
`endif
			end
			
			if (lras && lcode == 4'h2 && (st_num[2:0] == 3'd2 || st_num[2:0] == 3'd6) && lpage_opened) begin
				state[0].CMD  <= CTRL_CAS;
				state[0].ADDR <= {laddr,1'b0};
				state[0].WE   <= 1;
				state[0].BE   <= lwe;
				state[0].DATA <= din[31:16];
				state[0].BANK <= 2'd0;
`ifdef DEBUG
				dbg_cross_page <= (dbg_open_lpage != laddr[21:11]);
`endif
			end
			if (rras && rcode == 4'h2 && (st_num[2:0] == 3'd3 || st_num[2:0] == 3'd7) && rpage_opened) begin
				state[0].CMD  <= CTRL_CAS;
				state[0].ADDR <= {raddr,1'b0};
				state[0].WE   <= 1;
				state[0].BE   <= rwe;
				state[0].DATA <= din[15:0];
				state[0].BANK <= 2'd1;
`ifdef DEBUG
				dbg_cross_page <= (dbg_open_rpage != raddr[21:11]);
`endif
			end
			
			if (lras && (lcode == 4'h4 || lcode == 4'hC) && st_num[2:0] == 3'd4) begin
				state[0].CMD  <= CTRL_RAS;
				state[0].BANK <= 2'd0;
				state[0].RFS  <= 1;
			end
			else if ((rfs && !rfs_old) || (!rfs && rfs_old)) begin
				state[0].CMD  <= CTRL_RAS;
				state[0].BANK <= 2'd0;
				state[0].RFS  <= 1;  
			end
			
			if (!lras && lpage_opened && st_num[2:0] == 3'd0) begin
				state[0].CMD  <= CTRL_PRE;
				state[0].BANK <= 2'd0;
				lpage_opened <= 0;
			end
			if (!rras && rpage_opened && st_num[2:0] == 3'd1) begin
				state[0].CMD  <= CTRL_PRE;
				state[0].BANK <= 2'd1;
				rpage_opened <= 0;
			end
		end
	end
	always @(posedge clk) begin
		state[1] <= state[0];
		state[2] <= state[1];
		state[3] <= state[2];
		state[4] <= state[3];
		state[5] <= state[4];
	end
	
	wire [ 1:0] ctrl_cmd   = state[0].CMD;
	wire [22:1] ctrl_addr  = state[0].ADDR;
	wire [15:0] ctrl_data  = state[0].DATA;
//	wire        ctrl_rd    = state[0].RD;
	wire        ctrl_we    = state[0].WE;
	wire [ 1:0] ctrl_be    = state[0].BE;
	wire [ 1:0] ctrl_bank  = state[0].BANK;
	wire        ctrl_rfs   = state[0].RFS;
	
	wire       data_read0 = state[3].RD;
	wire       data_read1  = state[4].RD;
	wire       out_read0  = state[4].RD;
	wire       out_read1  = state[5].RD;
	wire       out_bank  = state[5].BANK[0];
	
	reg [31:0] rbuf;
	always @(posedge clk) begin
		rbuf <= {rbuf[15:0],SDRAM_DQ};
		if (out_read1) dout <= rbuf;
	end
	

	localparam CMD_NOP             = 3'b111;
	localparam CMD_ACTIVE          = 3'b011;
	localparam CMD_READ            = 3'b101;
	localparam CMD_WRITE           = 3'b100;
	localparam CMD_BURST_TERMINATE = 3'b110;
	localparam CMD_PRECHARGE       = 3'b010;
	localparam CMD_AUTO_REFRESH    = 3'b001;
	localparam CMD_LOAD_MODE       = 3'b000;
	
	// SDRAM state machines
	wire [22:1] a = ctrl_addr;
	wire [15:0] d = ctrl_data;
	wire  [1:0] dqm = ~ctrl_be;
	always @(posedge clk) begin
		if (ctrl_cmd == CTRL_RAS || ctrl_cmd == CTRL_CAS || ctrl_cmd == CTRL_PRE) SDRAM_BA <= (mode == MODE_NORMAL) ? ctrl_bank : 2'b00;

		casex({init_done,ctrl_rfs,ctrl_we,mode,ctrl_cmd})
			{3'bX0X, MODE_NORMAL, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_ACTIVE,1'b0};
			{3'bX1X, MODE_NORMAL, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_AUTO_REFRESH,1'b0};
			{3'b101, MODE_NORMAL, CTRL_CAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_WRITE,1'b0};
			{3'b100, MODE_NORMAL, CTRL_CAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_READ,1'b0};
			{3'b10X, MODE_NORMAL, CTRL_PRE}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_PRECHARGE,1'b0};

			// init
			{3'bXXX,    MODE_LDM, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_LOAD_MODE, 1'b0};
			{3'bXXX,    MODE_PRE, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_PRECHARGE, 1'b0};

										   default: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_NOP,1'b1};
		endcase
		
		SDRAM_DQ <= 'Z;
		casex({init_done,ctrl_rfs,ctrl_we,mode,ctrl_cmd})
			{3'b101, MODE_NORMAL, CTRL_CAS}: begin 
				SDRAM_DQ <= d; 
`ifdef DEBUG
				dbg_sdram_d <= d;
`endif
			end
										   default: ;
		endcase

		if (mode == MODE_NORMAL) begin
			casex ({ctrl_we,ctrl_cmd})
				{1'bX,CTRL_RAS}: SDRAM_A <= {1'b0,a[22:11]};
				{1'b0,CTRL_CAS}: SDRAM_A <= {2'b00,1'b0,a[10:1]};
				{1'b1,CTRL_CAS}: SDRAM_A <= {dqm  ,1'b0,a[10:1]};
				{1'bX,CTRL_PRE}: SDRAM_A <= {2'b00,1'b0,10'b0000000000};
			endcase;
		end
		else if (mode == MODE_LDM && ctrl_cmd == CTRL_RAS) SDRAM_A <= MODE;
		else if (mode == MODE_PRE && ctrl_cmd == CTRL_RAS) SDRAM_A <= 13'b0010000000000;
		else SDRAM_A <= '0;
	end
	
	assign SDRAM_CKE = 1;
	assign {SDRAM_DQMH,SDRAM_DQML} = SDRAM_A[12:11];
	
	
`ifdef DEBUG
	always @(posedge clk) begin
		reg [31: 0] div_cnt;
		reg [23: 0] num_cnt;
		
		if (ctrl_rfs) num_cnt <= num_cnt + 32'd1;
		
		div_cnt <= div_cnt + 1;
		if (div_cnt == 6400000) begin
			div_cnt <= '0;
			dbg_numrfs_in_64ms <= num_cnt;
			num_cnt <= '0;
		end
	end
	assign dbg_ctrl_bank = ctrl_bank;
	assign dbg_ctrl_cmd = ctrl_cmd;
	assign dbg_ctrl_we = ctrl_we;
	assign dbg_ctrl_rfs = ctrl_rfs;
	assign dbg_data_read = data_read0;
	assign dbg_out_read = out_read0;
	assign dbg_out_bank = out_bank;
`endif

	altddio_out
	#(
		.extend_oe_disable("OFF"),
		.intended_device_family("Cyclone V"),
		.invert_output("OFF"),
		.lpm_hint("UNUSED"),
		.lpm_type("altddio_out"),
		.oe_reg("UNREGISTERED"),
		.power_up_high("OFF"),
		.width(1)
	)
	sdramclk_ddr
	(
		.datain_h(1'b0),
		.datain_l(1'b1),
		.outclock(clk),
		.dataout(SDRAM_CLK),
		.aclr(1'b0),
		.aset(1'b0),
		.oe(1'b1),
		.outclocken(1'b1),
		.sclr(1'b0),
		.sset(1'b0)
	);

endmodule
