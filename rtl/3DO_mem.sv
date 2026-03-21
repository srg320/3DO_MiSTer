module VRAM_SHIFTREG 
#( parameter addr_width = 9 )
(
	input                    CLK,
	input  [addr_width-4: 1] WADDR,
	input  [         255: 0] DATA,
	input  [           7: 0] WREN,
	input  [addr_width-4: 1] RADDR,
	output [         255: 0] Q
);

	wire [255:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WADDR),
				.address_b (RADDR),
				.clock0 (CLK),
				.clock1 (CLK),
				.data_a (DATA),
				.wren_a (|WREN),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a ({{4{WREN[7]}},{4{WREN[6]}},{4{WREN[5]}},{4{WREN[4]}},{4{WREN[3]}},{4{WREN[2]}},{4{WREN[1]}},{4{WREN[0]}}}),
				.byteena_b (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({32*8{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK1",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**(addr_width-4),
		altsyncram_component.numwords_b = 2**(addr_width-4),
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.widthad_a = addr_width-4,
		altsyncram_component.widthad_b = addr_width-4,
		altsyncram_component.width_a = 32*8,
		altsyncram_component.width_b = 32*8,
		altsyncram_component.byte_size = 8,
		altsyncram_component.width_byteena_a = 32;
		
	assign Q = sub_wire0;

endmodule

module VRAM_MEM 
#( parameter addr_width = 16 )
(
	input                    CLK,
	input  [addr_width-1: 0] ADDR,
	input  [          15: 0] DATA,
	input  [           1: 0] WREN,
	output [          15: 0] Q,
	
	input                    SCLK,
	input  [addr_width-1: 4] SADDR,
	input  [         255: 0] SDATA,
	input                    SWREN,
	output [         255: 0] SQ
);
	
	wire [15:0] sub_wire0;
	wire [255:0] sub_wire1;

	altsyncram	altsyncram_component (
				.address_a (ADDR),
				.address_b (SADDR),
				.clock0 (CLK),
				.clock1 (SCLK),
				.data_a (DATA),
				.data_b (SDATA),
				.wren_a (|WREN),
				.wren_b (SWREN),
				.q_a (sub_wire0),
				.q_b (sub_wire1),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (WREN),
				.byteena_b (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.eccstatus (),
				.rden_a (1'b1),
				.rden_b (1'b1));
	defparam
		altsyncram_component.address_reg_b = "CLOCK1",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.indata_reg_b = "CLOCK1",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**addr_width,
		altsyncram_component.numwords_b = 2**(addr_width-4),
		altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",		
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = addr_width,
		altsyncram_component.widthad_b = addr_width-4,
		altsyncram_component.width_a = 16,
		altsyncram_component.width_b = 256,
		altsyncram_component.width_byteena_a = 2,
//		altsyncram_component.width_byteena_b = 1,
		altsyncram_component.init_file = ""; 

	assign Q = sub_wire0;
	assign SQ = sub_wire1;

endmodule


