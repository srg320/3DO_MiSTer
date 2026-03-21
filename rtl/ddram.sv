module ddram
(
	output         DDRAM_CLK,
	input          DDRAM_BUSY,
	output [ 7: 0] DDRAM_BURSTCNT,
	output [28: 0] DDRAM_ADDR,
	input  [63: 0] DDRAM_DOUT,
	input          DDRAM_DOUT_READY,
	output         DDRAM_RD,
	output [63: 0] DDRAM_DIN,
	output [ 7: 0] DDRAM_BE,
	output         DDRAM_WE,
	
	input          clk,
	input          rst,
	
	input  [27: 2] io_addr,
	output [31: 0] io_dout,
	input  [31: 0] io_din,
	input          io_rd,
	input  [ 3: 0] io_we,
	output         io_busy,

	input          sclk,
	input  [19: 2] laddr,
	input  [15: 0] ldin,
	output [15: 0] ldout,
	input          lras,
	input  [ 1: 0] lwe,
	input          lrd,
	input  [19: 2] raddr,
	input  [15: 0] rdin,
	output [15: 0] rdout,
	input          rras,
	input  [ 1: 0] rwe,
	input          rrd,
	output         busy,
	
	input  [19: 2] bladdr,
	input          blwr,
	input          blrd,
	input  [19: 2] braddr,
	input          brwr,
	input          brrd,
	output [ 9: 2] ba,
	input  [63: 0] bin,
	output [63: 0] bout,
	output         blte,
	output         brte,
	output         bbusy
);

	reg  [ 27:  1] ram_address;
	reg  [ 63:  0] ram_din;
	reg  [  7:  0] ram_ba;
	reg  [  7:  0] ram_burst;
	reg            ram_read = 0;
	reg            ram_write = 0;
	
	reg            burst_read_lbusy = 0,burst_read_rbusy = 0;
	reg            burst_write_lbusy = 0,burst_write_rbusy = 0;
	reg            read_lbusy = 0,read_rbusy = 0;
	reg            write_lpend = 0,write_rpend = 0;
	reg            write_lbusy = 0,write_rbusy = 0;
	reg            write_lcache_update,write_rcache_update;
	reg            io_read_busy = 0;
	reg            io_write_busy = 0;

	reg  [ 19:  2] burst_laddr,burst_raddr;
	reg  [ 19:  2] write_laddr,write_raddr;
	reg  [ 15:  0] write_ldata,write_rdata;
	reg  [  1:  0] write_lbe,write_rbe;
	reg  [ 19:  2] read_laddr = '1,read_raddr = '1;
	reg            read_lact,read_ract;
	reg  [ 27:  2] io_write_addr;
	reg  [ 31:  0] io_write_data;
	reg  [  3:  0] io_write_be;
	reg  [ 27:  2] io_read_addr;
	reg  [ 31:  0] io_rbuf;

	reg  [  3:  0] state = 0;
	reg  [  7:  0] rpos,wpos = '0;
	reg  [  3:  0] lcache_wren,rcache_wren;

	always @(posedge clk) begin
		bit old_io_rd, old_io_we;
		bit old_blrd, old_blwr, old_brrd, old_brwr;
		bit old_lras, old_lrd, old_lwe, old_rras, old_rrd, old_rwe;
		bit old_rst;
		bit read_lprepend,read_rprepend;
		bit read_lpend,read_rpend;
		bit write_lprepend,write_rprepend;
		bit burst_lact,burst_ract;
		bit burst_write;
		bit [7:0] burst_ba;
		bit [19:2] laddr_ff,raddr_ff;
		
		old_blwr <= blwr; old_brwr <= brwr;
		old_blrd <= blrd; old_brrd <= brrd;
		old_lras <= lras; old_rras <= rras;
		old_lrd <= lrd; old_rrd <= rrd;
		old_lwe <= |lwe; old_rwe <= |rwe;
		old_rst <= rst;
		
		if (rst) begin
			burst_write_lbusy <= 0;
		end else if (blwr && !old_blwr) begin
			burst_laddr <= bladdr;
			burst_write_lbusy <= 1;
		end
		if (rst) begin
			burst_write_rbusy <= 0;
		end else if (brwr && !old_brwr) begin
			burst_raddr <= braddr;
			burst_write_rbusy <= 1;
		end
		if (rst) begin
			burst_read_lbusy <= 0;
		end else if (blrd && !old_blrd) begin
			burst_laddr <= bladdr;
			burst_read_lbusy <= 1;
		end
		if (rst) begin
			burst_read_rbusy <= 0;
		end else if (brrd && !old_brrd) begin
			burst_raddr <= braddr;
			burst_read_rbusy <= 1;
		end
		
		laddr_ff <= laddr;
		raddr_ff <= raddr;
		if (rst) begin
			read_lprepend <= 0;
			read_lbusy <= 0;
		end else if (lrd && !old_lrd && lras && old_lras) begin
			read_lprepend <= 1;
			read_laddr <= laddr;
			if (read_laddr[19:7] != laddr[19:7]) begin
				read_lbusy <= 1;
			end
		end
		if (rst) begin
			read_rprepend <= 0;
			read_rbusy <= 0;
		end else if (rrd && !old_rrd && rras && old_rras) begin
			read_rprepend <= 1;
			read_raddr <= raddr;
			if (read_raddr[19:7] != raddr[19:7]) begin
				read_rbusy <= 1;
			end
		end
//		if (rst) begin
//			read_laddr <= '1;
//			read_lpend <= 0;
//		end else if (read_lprepend) begin
//			read_lprepend <= 0;
//			read_laddr <= laddr_ff;
//			read_lpend <= 1;
//		end
//		if (rst) begin
//			read_raddr <= '1;
//			read_rpend <= 0;
//		end else if (read_rprepend) begin
//			read_rprepend <= 0;
//			read_raddr <= raddr_ff;
//			read_rpend <= 1;
//		end
		
		if (rst) begin
			write_lprepend <= 0;
			write_lbusy <= 0;
		end else if (|lwe && !old_lwe && lras && old_lras) begin
			write_lprepend <= 1;
			write_lbusy <= |state | DDRAM_BUSY;
		end
		if (rst) begin
			write_rprepend <= 0;
			write_rbusy <= 0;
		end else if (|rwe && !old_rwe && rras && old_rras) begin
			write_rprepend <= 1;
			write_rbusy <= |state | DDRAM_BUSY;
		end
		
		if (rst) begin
			write_lpend <= 0;
		end else if (write_lprepend && sclk) begin
			write_lprepend <= 0;
			if (read_laddr[19:7] == laddr[19:7]) begin
				write_lcache_update <= 1;
			end else begin
				write_lcache_update <= 0;
			end
			write_laddr <= laddr;
			write_ldata <= ldin;
			write_lbe <= lwe;
			write_lpend <= 1;
		end
		if (rst) begin
			write_rpend <= 0;
		end else if (write_rprepend && sclk) begin
			write_rprepend <= 0;
			if (read_raddr[19:7] == raddr[19:7]) begin
				write_rcache_update <= 1;
			end else begin
				write_rcache_update <= 0;
			end
			write_raddr <= raddr;
			write_rdata <= rdin;
			write_rbe <= rwe;
			write_rpend <= 1;
		end
		
		old_io_rd <= io_rd;
		old_io_we <= |io_we;
		if (rst && !old_rst) begin
			io_read_busy <= 0;
		end else if (io_rd && !old_io_rd) begin
			io_read_addr <= io_addr;
			io_read_busy <= 1;
		end
		if (rst && !old_rst) begin
			io_write_busy <= 0;
		end else if (|io_we && !old_io_we) begin
			io_write_addr <= io_addr;
			io_write_data <= io_din;
			io_write_be <= io_we;
			io_write_busy <= 1;
		end
		
		{blte,brte} <= 0;
		if (rst && !old_rst) begin
			state <= 0;
		end else if (!DDRAM_BUSY) begin
			burst_write <= 0;
			ram_write <= 0;
			ram_read  <= 0;
			case (state)
				0: begin
					if (burst_write_lbusy) begin 
						burst_lact <= 1;
						if (burst_write_rbusy && burst_raddr == burst_laddr) burst_ract <= 1;
						ram_address <= {8'b00000000,burst_laddr[19:3],2'b00};
						ram_burst   <= 128;
						wpos[6:0] <= '0;
						blte <= 1;
						if (burst_write_rbusy && burst_raddr == burst_laddr) brte <= 1;
						state       <= 4'd1;
					end
					else if (burst_write_rbusy) begin  
						burst_ract <= 1;
						ram_address <= {8'b00000000,burst_raddr[19:3],2'b00};
						ram_burst   <= 128;
						wpos[6:0] <= '0;
						brte <= 1;
						state       <= 4'd1;
					end
					else if (burst_read_lbusy) begin 
						burst_lact <= 1;
						if (burst_read_rbusy && burst_raddr == burst_laddr) burst_ract <= 1;
						ram_address <= {8'b00000000,burst_laddr[19:3],2'b00};
						ram_ba      <= 8'hFF;
						ram_read 	<= 1;
						ram_burst   <= 8'd128 - burst_laddr[9:3];
						rpos        <= {1'b0,burst_laddr[9:3]};
						state       <= 4'd2;
					end
					else if (burst_read_rbusy) begin 
						burst_ract <= 1;
						ram_address <= {8'b00000000,burst_raddr[19:3],2'b00};
						ram_ba      <= 8'hFF;
						ram_read 	<= 1;
						ram_burst   <= 8'd128 - burst_raddr[9:3];
						rpos        <= {1'b0,burst_raddr[9:3]};
						state       <= 4'd2;
					end
					else if (write_lpend && write_rpend && write_laddr == write_raddr) begin 
						{write_lpend,write_rpend} <= '0;
						{write_lbusy,write_rbusy} <= '0;
						lcache_wren <= !write_lcache_update ? 4'b0000 : !write_laddr[2] ? {write_lbe,2'b00} : {2'b00,write_lbe};
						rcache_wren <= !write_rcache_update ? 4'b0000 : !write_raddr[2] ? {write_rbe,2'b00} : {2'b00,write_rbe};
						ram_address <= {8'b00000000,write_laddr[19:3],2'b00};
						ram_din		<= {2{write_ldata,write_rdata}};
						ram_ba      <= (!write_laddr[2] ? {write_lbe,6'b000000} : {4'b0000,write_lbe,2'b00}) | (!write_raddr[2] ? {2'b00,write_rbe,4'b0000} : {6'b000000,write_rbe});
						ram_write 	<= 1;
						ram_burst   <= 1;
						state       <= 4'd3;
					end
					else if (write_lpend) begin 
						write_lpend <= 0;
						write_lbusy <= 0;
						lcache_wren <= !write_lcache_update ? 4'b0000 : !write_laddr[2] ? {write_lbe,2'b00} : {2'b00,write_lbe};
						ram_address <= {8'b00000000,write_laddr[19:3],2'b00};
						ram_din		<= {4{write_ldata}};
						ram_ba      <= !write_laddr[2] ? {write_lbe,6'b000000} : {4'b0000,write_lbe,2'b00};
						ram_write 	<= 1;
						ram_burst   <= 1;
						state       <= 4'd3;
					end
					else if (write_rpend) begin 
						write_rpend <= 0;
						write_rbusy <= 0;
						rcache_wren <= !write_rcache_update ? 4'b0000 : !write_raddr[2] ? {write_rbe,2'b00} : {2'b00,write_rbe};
						ram_address <= {8'b00000000,write_raddr[19:3],2'b00};
						ram_din		<= {4{write_rdata}};
						ram_ba      <= !write_raddr[2] ? {2'b00,write_rbe,4'b0000} : {6'b000000,write_rbe};
						ram_write 	<= 1;
						ram_burst   <= 1;
						state       <= 4'd3;
					end
					else if (read_lbusy) begin 
//						read_lpend <= 0;
						read_lact <= 1;
						if (read_rbusy && read_raddr == read_laddr) read_ract <= 1;
						ram_address <= {8'b00000000,read_laddr[19:7],6'b000000};
						ram_ba      <= 8'hFF;
						ram_read    <= 1;
						ram_burst   <= 16;
						rpos        <= '0;
						state       <= 4'd4;
					end
					else if (read_rbusy) begin 
//						read_rpend <= 0;
						read_ract <= 1;
						ram_address <= {8'b00000000,read_raddr[19:7],6'b000000};
						ram_ba      <= 8'hFF;
						ram_read    <= 1;
						ram_burst   <= 16;
						rpos        <= '0;
						state       <= 4'd4;
					end
					else if (io_write_busy) begin 
						ram_address <= {io_write_addr[27:3],2'b00};
						ram_din		<= {2{io_write_data}};
						ram_ba      <= !io_write_addr[2] ? {io_write_be,4'b0000} : {4'b0000,io_write_be};
						ram_write 	<= 1;
						ram_burst   <= 1;
						state       <= 4'd6;
					end
					else if (io_read_busy) begin 
						ram_address <= {io_read_addr[27:3],2'b00};
						ram_ba      <= 8'hFF;
						ram_read    <= 1;
						ram_burst   <= 1;
//						rpos        <= '0;
						state       <= 4'd7;
					end
				end
				
				4'd1: begin
					burst_write <= 1;
					burst_ba      <= {{2{burst_lact}},{2{burst_ract}},{2{burst_lact}},{2{burst_ract}}};
//					ram_din		<= bin;
//					ram_write 	<= 1;
//					ram_ba      <= {{2{burst_lact}},{2{burst_ract}},{2{burst_lact}},{2{burst_ract}}};
					ba <= wpos;
					if (wpos != 8'd127 && wpos != 8'd255) begin
						blte <= burst_lact;
						brte <= burst_ract;
					end
					wpos <= wpos + 8'd1;
					if (wpos == 8'd127) begin
						if (burst_lact) burst_laddr <= burst_laddr + 18'h00100;
						if (burst_ract) burst_raddr <= burst_raddr + 18'h00100;
						burst_lact <= 0;
						burst_ract <= 0;
						state <= 4'd9;
					end
					if (wpos == 8'd255) begin
						if (burst_lact) burst_write_lbusy <= 0;
						if (burst_ract) burst_write_rbusy <= 0;
						burst_lact <= 0;
						burst_ract <= 0;
						state <= burst_read_lbusy || burst_read_rbusy ? 4'd8 : 4'd9;
					end
				end
				
				4'd2: if (DDRAM_DOUT_READY) begin
					bout <= DDRAM_DOUT;
					ba <= rpos;
					blte <= burst_lact;
					brte <= burst_ract;
					rpos <= rpos + 8'd1;
					if (rpos[6:0] == 7'd127) begin
						if (burst_lact) burst_read_lbusy <= 0;
						if (burst_ract) burst_read_rbusy <= 0;
						burst_lact <= 0;
						burst_ract <= 0;
						state <= burst_write_lbusy || burst_write_rbusy ? 4'd8 : 4'd0;
					end
				end
				
				4'd3: begin
					lcache_wren <= '0;
					rcache_wren <= '0;
					state <= 4'd0;
				end
				
				4'd4: if (DDRAM_DOUT_READY) begin
					rpos[4:0] <= rpos[4:0] + 5'd2;
					if (rpos[4:0] == 5'h1E) begin
						if (read_lact) read_lbusy <= 0;
						if (read_ract) read_rbusy <= 0;
						read_lact <= 0;
						read_ract <= 0;
						state <= 4'd0;
					end
				end
				
				4'd5: if (DDRAM_DOUT_READY) begin
					rpos[2:0] <= rpos[2:0] + 3'd2;
					if (rpos[2:0] == 3'd6) begin
						state <= 4'd0;
					end
				end
				
				4'd6: begin
					io_write_busy <= 0;
					state <= 4'd0;
				end
				
				4'd7: if (DDRAM_DOUT_READY) begin
					io_rbuf <= !io_read_addr[2] ? DDRAM_DOUT[63:32] : DDRAM_DOUT[31:0];
					io_read_busy <= 0;
					state <= 4'd0;
				end
				
				4'd8: begin
					state <= 4'd9;
				end
				
				4'd9: begin
					state <= 4'd10;
				end
				
				4'd10: begin
					state <= 4'd0;
				end
			endcase
			
			if (burst_write) begin
				ram_din		<= bin;
				ram_write 	<= 1;
				ram_ba      <= burst_ba;
			end
		end
	end
	
	wire           lcache_load = (state == 4'd4) && read_lact && DDRAM_DOUT_READY && !DDRAM_BUSY;
	wire           rcache_load = (state == 4'd4) && read_ract && DDRAM_DOUT_READY && !DDRAM_BUSY;
	wire [ 31:  0] lcache_q,rcache_q;

	ddr_cache_ram #(4) lcache (clk, lcache_load ? rpos[4:1] : write_laddr[6:3], lcache_load ? {DDRAM_DOUT[63:48],DDRAM_DOUT[31:16]} : {2{write_ldata}}, ({4{lcache_load}} | lcache_wren), read_laddr[6:3], lcache_q);
	ddr_cache_ram #(4) rcache (clk, rcache_load ? rpos[4:1] : write_raddr[6:3], rcache_load ? {DDRAM_DOUT[47:32],DDRAM_DOUT[15:00]} : {2{write_rdata}}, ({4{rcache_load}} | rcache_wren), read_raddr[6:3], rcache_q);

	always_comb begin
		case (read_laddr[2])
			1'b0: ldout = lcache_q[31:16];
			1'b1: ldout = lcache_q[15:00];
		endcase
		
		case (read_raddr[2])
			1'b0: rdout = rcache_q[31:16];
			1'b1: rdout = rcache_q[15:00];
		endcase
	end
//	assign ldout = lbuf[read_laddr[5:2]];
//	assign rdout = rbuf[read_raddr[5:2]];
	assign busy = /*burst_read_lbusy | burst_read_rbusy | burst_write_lbusy | burst_write_rbusy |*/ write_lbusy | write_rbusy | read_lbusy | read_rbusy;
	assign bbusy = burst_read_lbusy | burst_read_rbusy | burst_write_lbusy | burst_write_rbusy;
	
	assign io_dout = io_rbuf;
	assign io_busy = io_read_busy | io_write_busy;
	
	assign DDRAM_CLK      = clk;
	assign DDRAM_BURSTCNT = ram_burst;
	assign DDRAM_BE       = ram_ba;
	assign DDRAM_ADDR     = {4'b0011, ram_address[27:3]}; // RAM at 0x30000000
	assign DDRAM_RD       = ram_read;
	assign DDRAM_DIN      = ram_din;
	assign DDRAM_WE       = ram_write;

endmodule

module ddr_cache_ram #(parameter wa = 3) (
	clock,
	wraddress,
	data,
	wren,
	rdaddress,
	q);

	input	  clock;
	input	[wa-1:0]  wraddress;
	input	[31:0] data;
	input	[3:0] wren;
	input	[wa-1:0]  rdaddress;
	output	[31:0]  q;

	wire [31:0] sub_wire0;

	altdpram	altdpram_component (
				.data (data),
				.inclock (clock),
				.rdaddress (rdaddress),
				.wraddress (wraddress),
				.wren (|wren),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (wren),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
				//.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.power_up_uninitialized = "TRUE",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 32,
		altdpram_component.widthad = wa,
		altdpram_component.byte_size = 8,
		altdpram_component.width_byteena = 4,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";

	wire [31:0] q = sub_wire0;
	
endmodule
