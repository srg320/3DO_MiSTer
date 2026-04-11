//============================================================================
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

	assign ADC_BUS  = 'Z;
	assign {UART_RTS, UART_TXD, UART_DTR} = 0;
	assign BUTTONS   = {1'b0,osd_btn};
	assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
	assign USER_OUT = '0;
	
	assign AUDIO_S = 1;
	assign AUDIO_MIX = 0;
	assign HDMI_FREEZE = 0;
	assign HDMI_BLACKOUT = 0;
	assign HDMI_BOB_DEINT = 0;
	
	assign LED_DISK  = 0;
	assign LED_POWER = 0;
	assign LED_USER  = bios_download;
	assign VGA_SCALER= 0;
	assign VGA_DISABLE = 0;
	
//	assign {SDRAM2_DQ, SDRAM2_CLK,SDRAM2_A,SDRAM2_BA,SDRAM2_nCS,SDRAM2_nCAS,SDRAM2_nRAS,SDRAM2_nWE} = 'Z;
	
	///////////////////////  CLOCK/RESET  ///////////////////////////////////
	wire clk_sys, clk_mem, clk_vid, locked;

	pll pll
	(
		.refclk(CLK_50M),
		.rst(0),
		.outclk_0(clk_sys),
		.outclk_1(clk_mem),
		.outclk_2(clk_vid),
		.locked(locked)
	);

	///////////////////////////////////////////////////
	
	// Status Bit Map:
	//             Upper                             Lower              
	// 0         1         2         3          4         5         6   
	// 01234567890123456789012345678901 23456789012345678901234567890123
	// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
	// XXXXXXXXXXX XXX                  XXXXXX                          
	
	`include "build_id.v"
	localparam CONF_STR = {
		"3DO;;",
		"S0,CUEISO,Insert Disk;",
		"FS2,BIN,Load bios;",
//		"-;",
//		"OF,Load from CD,No,Yes;",

		"-;",
		"D0RC,Load Backup RAM;",
		"D0RD,Save Backup RAM;",
		"D0OE,Autosave,Off,On;",
		"D0-;",
		
		"-;",
		"P1,Audio & Video;",
		"P1-;",
		"P1O4,Aspect Ratio,4:3,16:9;",
		"P1O5,320x224 Aspect,Original,Corrected;",
		"P1O13,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
		"P1-;",
		"P1O67,Composite Blend,Off,On,Adaptive;",
	
		"P2,Input;",
		"P2O[34:32],Pad 1,Digital,Mouse,Flightstick,Off;",
		"P2-;",
		"d1P2O[37:35],Pad 2,Digital,Mouse,Flightstick,Off;",
		"P2-;",

//		"P3,Hardware;",
//		"P3-;",
//		"P3O8A,FB offset,H200000,H240000,H260000,H280000,H2A0000;",
		
		"-;",
		"R0,Reset;",
		"J1,A,B,C,P,X,R,L,T;",
		"V,v",`BUILD_DATE
	};

	wire [63:0] status;
	wire [15:0] status_menumask = {14'd0, (status[34:32] == 3'd0), ~bk_ena};
	
	wire  [1:0] buttons;
	wire [12:0] joystick_0,joystick_1,joystick_2,joystick_3,joystick_4;
	wire  [7:0] joy0_x0,joy0_y0,joy0_x1,joy0_y1,joy1_x0,joy1_y0,joy1_x1,joy1_y1;
	wire        ioctl_download;
	wire        ioctl_wr;
	wire [24:0] ioctl_addr;
	wire [15:0] ioctl_data;
	wire  [7:0] ioctl_index;
	reg         ioctl_wait = 0;
	
	reg  [31:0] sd_lba = '0;
	reg         sd_rd = 0;
	reg         sd_wr = 0;
	wire        sd_ack;
	wire  [7:0] sd_buff_addr;
	wire [15:0] sd_buff_dout;
	wire [15:0] sd_buff_din;
	wire        sd_buff_wr;
	wire        img_mounted;
	wire        img_readonly;
	wire [63:0] img_size;
	
	wire        forced_scandoubler;
	wire [10:0] ps2_key;
	wire [24:0] ps2_mouse;
	
	wire [35:0] EXT_BUS;
	
	wire [21:0] gamma_bus;
	wire [15:0] sdram_sz;
	
	hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io
	(
		.clk_sys(clk_sys),
		.HPS_BUS(HPS_BUS),
	
		.joystick_0(joystick_0),
		.joystick_1(joystick_1),
		.joystick_2(joystick_2),
		.joystick_3(joystick_3),
		.joystick_4(joystick_4),
		.joystick_l_analog_0({joy0_y0, joy0_x0}),
		.joystick_l_analog_1({joy1_y0, joy1_x0}),
		.joystick_r_analog_0({joy0_y1, joy0_x1}),
		.joystick_r_analog_1({joy1_y1, joy1_x1}),
	
		.buttons(buttons),
		.forced_scandoubler(forced_scandoubler),
		.new_vmode(new_vmode),
	
		.status(status),
		.status_in(status),
		.status_set(0),
		.status_menumask(status_menumask),
	
		.ioctl_download(ioctl_download),
		.ioctl_index(ioctl_index),
		.ioctl_wr(ioctl_wr),
		.ioctl_addr(ioctl_addr),
		.ioctl_dout(ioctl_data),
		.ioctl_wait(ioctl_wait),
	
		.sd_lba('{sd_lba}),
		.sd_rd(sd_rd),
		.sd_wr(sd_wr),
		.sd_ack(sd_ack),
		.sd_buff_addr(sd_buff_addr),
		.sd_buff_dout(sd_buff_dout),
		.sd_buff_din('{sd_buff_din}),
		.sd_buff_wr(sd_buff_wr),
		.img_mounted(img_mounted),
		.img_readonly(img_readonly),
		.img_size(img_size),
	
		.gamma_bus(gamma_bus),
		.sdram_sz(sdram_sz),
	
		.ps2_key(ps2_key),
		.ps2_mouse(ps2_mouse),
	
		.EXT_BUS(EXT_BUS)
	);
	
	wire bios_download = ioctl_download & (ioctl_index[5:2] == 4'b0000 && ioctl_index[1:0] != 2'h3);
	wire kanji_download = ioctl_download & (ioctl_index[5:2] == 4'b0000 && ioctl_index[1:0] == 2'h3);
	wire cdd_data_download = ioctl_download & (ioctl_index[5:2] == 4'b0010);
	wire cdd_info_download = ioctl_download & (ioctl_index[5:2] == 4'b0011);
	wire save_download = ioctl_download & (ioctl_index[5:2] == 4'b0001);
	
	reg osd_btn = 0;
//	always @(posedge clk_sys) begin
//		integer timeout = 0;
//		reg     has_bootrom = 0;
//		reg     last_rst = 0;
//	
//		if (RESET) last_rst = 0;
//		if (status[0]) last_rst = 1;
//	
//		if (bios_download & ioctl_wr & status[0]) has_bootrom <= 1;
//	
//		if(last_rst & ~status[0]) begin
//			osd_btn <= 0;
//			if(timeout < 24000000) begin
//				timeout <= timeout + 1;
//				osd_btn <= ~has_bootrom;
//			end
//		end
//	end
	
	reg reset = 1, mem_rst = 1;
	always @(posedge clk_sys) begin
		reset <= RESET | status[0] | buttons[1] | bios_download;
		mem_rst <= RESET | status[0] | buttons[1];
	end
	
	wire [15:0] joy0_data = {1'b1, 2'b00, joystick_0[2], joystick_0[3], joystick_0[0], joystick_0[1], joystick_0[4], joystick_0[5], joystick_0[6], joystick_0[7], joystick_0[8], joystick_0[9], joystick_0[10], 2'b00};
	wire [15:0] joy1_data = {1'b1, 2'b00, joystick_1[2], joystick_1[3], joystick_1[0], joystick_1[1], joystick_1[4], joystick_1[5], joystick_1[6], joystick_1[7], joystick_1[8], joystick_1[9], joystick_1[10], 2'b00};
	

`ifdef DEBUG
`define USE_BRAM_BLOCKS_FOR_VRAM 0
`else
`define USE_BRAM_BLOCKS_FOR_VRAM 1
`endif

	/*Frambuffer position in games:
	Alone in the Dark (US): 0x248800
	Cannon Fodder (US): 0x2AE800/0x2D2800
	Casper (US): 0x200000/0x225800/0x24B000
	DeathKeep (US): 0x250000/0x278000 (FMV only)
	FIFA International Soccer (US, Korea): 0x2AC000/0x2D2000
	Gex (US, EU): 0x25C800/0x282000/0x2A7800/0x2CD000 (FMV only)
	Psychic Detective (US) (Disc 1): 0x28B800/0x2B1000
	Quarantine (US): 0x274BA4
	Road & Track Presents - The Need for Speed (US, EU): 0x2AD000/0x2D3000
	Seal of the Pharaoh (US): 0x270800/0x296000
	Most others: 0x200000/0x225800
	*/
	
	//FPGA has enough BRAM to replace 0x60000 bytes (out of 0x100000 bytes) of VRAM. 
	//Of these, 0x5C000 bytes start at BRAM_OFFS*0x10000, while the remaining 0x4000 bytes always start at offset 0xFC000 (VDL). 
	reg  [ 3: 0] BRAM_OFFS;
	reg          NEED_DSP_PAUSE;
	always @(posedge clk_sys) begin
		reg [31: 0] msf,id;
	
		if (cdd_info_download && ioctl_wr) begin
			if (ioctl_addr == 25'h004) begin
				msf[31:16] <= {ioctl_data[7:0],ioctl_data[15:8]};
			end 
			if (ioctl_addr == 25'h006) begin
				msf[15:0] <= {ioctl_data[7:0],ioctl_data[15:8]};
			end 
			
			if (ioctl_addr == 25'h458) begin
				id[31:16] <= {ioctl_data[7:0],ioctl_data[15:8]};
			end 
			if (ioctl_addr == 25'h45A) begin
				id[15:0] <= {ioctl_data[7:0],ioctl_data[15:8]};
			end 
			if (ioctl_addr == 25'h480) begin
				BRAM_OFFS <= 4'h0;
				NEED_DSP_PAUSE <= 0;
				if (id == 32'h274E924C) BRAM_OFFS <= 4'h2;//Alone in the Dark (US)
				if (id == 32'h0340842C) BRAM_OFFS <= 4'hA;//Cannon Fodder (US)
				if (id == 32'h2D731C98) BRAM_OFFS <= 4'hA;//FIFA International Soccer (US, Korea)
				if (id == 32'h2584F855) BRAM_OFFS <= 4'h8;//Psychic Detective (US) (Disc 1)
				if (id == 32'h031BED09) BRAM_OFFS <= 4'h6;//Quarantine (US)
				if (id == 32'h06DE0DC2) BRAM_OFFS <= 4'hA;//Road & Track Presents - The Need for Speed (US, EU)
				if (id == 32'h2D95DCB6) BRAM_OFFS <= 4'h6;//Seal of the Pharaoh (US)
				if (id == 32'h213128DD) BRAM_OFFS <= 4'h8;//Live! 3DO Magazine CD-ROM 1 (Japan)
				
				if (id == 32'h25609184                       ) NEED_DSP_PAUSE <= 1;//Blade Force (US)
				if (id == 32'h043DCD69 && msf == 32'h69026900) NEED_DSP_PAUSE <= 1;//Decathlon (US) (Unl)
				if (id == 32'h0A9B739E                       ) NEED_DSP_PAUSE <= 1;//Killing Time (US) (RE1)
				if (id == 32'h06065D10                       ) NEED_DSP_PAUSE <= 1;//Snow Job Starring Tracy Scoggins (US)
			end
		end
	end
	
	wire [23: 2] LA;
	wire         LRAS0_N;
	wire         LRAS2_N;
	wire         LRAS3_N;
	wire         LCAS_N;
	wire [ 1: 0] LWE_N;
	wire         LOE_N;
	wire         LDSF;
	wire         LSC;
	wire         LQSF;
	wire [ 3: 0] LCODE;
	wire [23: 2] RA;
	wire         RRAS0_N;
	wire         RRAS2_N;
	wire         RRAS3_N;
	wire         RCAS_N;
	wire [ 1: 0] RWE_N;
	wire         ROE_N;
	wire         RDSF;
	wire         RSC;
	wire         RQSF;
	wire [ 3: 0] RCODE;
	wire [31: 0] RAM_DI;
	wire [31: 0] RAM_DO;
	
	wire         PBDIN;
	wire         PBDOUT;
	wire         PBCLK;
	
	wire [19: 0] PA;
	wire [31: 0] PDI;
	wire [ 7: 0] PDO;
	wire         ROMCS_N;
	wire         SRAMW_N;
	wire         SRAMR_N;
	
	wire         ROM_SEL;
	
	wire [ 7: 0] CDDI;
	wire [ 7: 0] CDDO;
	wire         CDEN_N;
	wire         CDCMD_N;
	wire         CDHWR_N;
	wire         CDHRD_N;
	wire         CDRST_N;
	wire         CDSTEN_N;
	wire         CDDTEN_N;
	wire         CDMDCHG;
	wire [15: 0] CDCRC;
	
	wire [31: 0] VRAM_SQ;
	
	wire [ 7: 0] R, G, B;
	wire         HS_N,VS_N;
	wire         DCLK;
	wire         HBL_N, VBL_N;
	wire         FIELD = 0;
	wire         INTERLACE = 0;
	
	wire         MCLK_CE;

	wire [31:0] in_clk = 50000000;
	
	bit CLK_DIV;
	always @(posedge clk_sys) 
		CLK_DIV <= ~CLK_DIV;
	wire CE_R =  CLK_DIV;
	wire CE_F = ~CLK_DIV;
		
	wire SYS_CE_R = CE_R;
	wire SYS_CE_F = CE_F;
	
	wire VCE;	//Video clock
	CEGen VCE_CEGen
	(
		.CLK(clk_sys),
		.RST_N(1),
		.IN_CLK(in_clk),
		.OUT_CLK(24545400),
		.CE(VCE)
	);
	
	wire ACLK_CE;	//Audio clock
	CEGen AUD_CEGen
	(
		.CLK(clk_sys),
		.RST_N(1),
		.IN_CLK(in_clk),
		.OUT_CLK(16934400),
		.CE(ACLK_CE)
	);
	
	reg POWER_ON;
	always @(posedge clk_sys) begin
		if (reset) POWER_ON <= 1;
		else if (CE_R) POWER_ON <= 0;
	end
	
	P3DO p3do
	(
		.RST_N(~reset),
		.CLK(clk_sys),
		.VCLK(clk_vid),
		.EN(1),
		.PAUSE(pause),
		.DSP_PAUSE(pause & NEED_DSP_PAUSE),
		
		.CE_F(SYS_CE_F),
		.CE_R(SYS_CE_R),
		
		.PON(POWER_ON),
				
		.LA(LA),
		.LRAS0_N(LRAS0_N),
		.LRAS2_N(LRAS2_N),
		.LRAS3_N(LRAS3_N),
		.LCAS_N(LCAS_N),
		.LWE_N(LWE_N),
		.LOE_N(LOE_N),
		.LDSF(LDSF),
		.LSC(LSC),
		.LQSF(LQSF),
		.LCODE(LCODE),
		.RA(RA),
		.RRAS0_N(RRAS0_N),
		.RRAS2_N(RRAS2_N),
		.RRAS3_N(RRAS3_N),
		.RCAS_N(RCAS_N),
		.RWE_N(RWE_N),
		.ROE_N(ROE_N),
		.RDSF(RDSF),
		.RSC(RSC),
		.RQSF(RQSF),
		.RCODE(RCODE),
		.DI(RAM_DI),
		.DO(RAM_DO),
		
		.PBDIN(PBDIN),
		.PBDOUT(PBDOUT),
		.PBCLK(PBCLK),
			
		.PA(PA),
		.PDI(PDI),
		.PDO(PDO),
		.ROMCS_N(ROMCS_N),
		.SRAMW_N(SRAMW_N),
		.SRAMR_N(SRAMR_N),
		
		.ROM_SEL(ROM_SEL),
		
		.CDDI(CDDI),
		.CDDO(CDDO),
		.CDEN_N(CDEN_N),
		.CDCMD_N(CDCMD_N),
		.CDHWR_N(CDHWR_N),
		.CDHRD_N(CDHRD_N),
		.CDRST_N(CDRST_N),
		.CDSTEN_N(CDSTEN_N),
		.CDDTEN_N(CDDTEN_N),
		.CDMDCHG(CDMDCHG),
		
		.S(VRAM_SQ),
		
		.VCE(VCE),
		.RGB({R,G,B}),
		.HS_N(HS_N),
		.VS_N(VS_N),
		.HBLK_N(HBL_N),
		.VBLK_N(VBL_N),
		.DCLK(DCLK),
		
		.ACLK_CE(ACLK_CE),
		.AUDIOL(AUDIO_L),
		.AUDIOR(AUDIO_R),
		
		.MCLK_CE(MCLK_CE),
		
		.SCRN_EN(SCRN_EN[2:0]),
		.DBG_EXT(DBG_EXT)
	);
	
	P3DO_CDROM cdrom
	(
		.RST_N(~reset),
		.CLK(clk_sys),
		.EN(1),
		
		.CE(CE_R),
		
		.CDDI(CDDO),
		.CDDO(CDDI),
		.CDEN_N(CDEN_N),
		.CDCMD_N(CDCMD_N),
		.CDHWR_N(CDHWR_N),
		.CDHRD_N(CDHRD_N),
		.CDRST_N(CDRST_N),
		.CDSTEN_N(CDSTEN_N),
		.CDDTEN_N(CDDTEN_N),
		.CDMDCHG(CDMDCHG),
		
		.CDD_DATA(ioctl_data),
		.CDD_WR(ioctl_wr),
		.CDD_DTEN(cdd_data_download),
		.CDD_DIEN(cdd_info_download),
	
		.DISCIN(1'b1/*status[15]*/),
		.EXT_BUS(EXT_BUS)
	);
	
	wire [ 2: 0] pad1_sel = status[34:32];
	wire [ 2: 0] pad2_sel = status[37:35];
	wire [ 2: 0] pad2_eff = (pad1_sel == 3'd0) ? pad2_sel : 3'd3;
	wire         pad_latch;
	
	function automatic [7:0] stick_axis(input signed [7:0] axis);
		reg signed [8:0] v;
		begin
			v = {axis[7],axis} + 9'd128;
			stick_axis = v[7:0];
		end
	endfunction

	function automatic signed [10:0] mouse_delta(input ovf, input sign, input [7:0] data);
		begin
			if (ovf) mouse_delta = sign ? -11'sd1024 : 11'sd1022;
			else     mouse_delta = $signed({sign,sign,sign,data}) <<< 1;
		end
	endfunction

	function automatic signed [10:0] mouse_limit(input signed [11:0] axis);
		begin
			if (axis > 12'sd1023) mouse_limit = 11'sd1023;
			else if (axis < -12'sd1024) mouse_limit = -11'sd1024;
			else mouse_limit = axis[10:0];
		end
	endfunction

	function automatic signed [9:0] mouse_step(input signed [10:0] axis);
		begin
			if (axis > 11'sd96) mouse_step = 10'sd96;
			else if (axis < -11'sd96) mouse_step = -10'sd96;
			else mouse_step = axis[9:0];
		end
	endfunction
	
	wire [7:0] stick0_x = stick_axis($signed(joy0_x0));
	wire [7:0] stick0_y = stick_axis($signed(joy0_y0));
	wire [7:0] stick0_z = stick_axis($signed(joy0_y1));
	wire [7:0] stick1_x = stick_axis($signed(joy1_x0));
	wire [7:0] stick1_y = stick_axis($signed(joy1_y0));
	wire [7:0] stick1_z = stick_axis($signed(joy1_y1));
	
	wire [7:0] mouse_flags = ps2_mouse[7:0];
	wire       mouse_ena = (pad1_sel == 3'd1) || (pad2_eff == 3'd1);
	wire signed [10:0] mouse_dx = mouse_delta(mouse_flags[6], mouse_flags[4], ps2_mouse[15:8]);
	wire signed [10:0] mouse_dy = mouse_delta(mouse_flags[7], mouse_flags[5], ps2_mouse[23:16]);
	
	reg mouse_toggle = 0;
	reg mouse_left = 0;
	reg mouse_middle = 0;
	reg mouse_right = 0;
	reg signed [10:0] mouse_x_acc = '0;
	reg signed [10:0] mouse_y_acc = '0;
	wire signed [9:0] mouse_x = mouse_step(mouse_x_acc);
	wire signed [9:0] mouse_y = mouse_step(mouse_y_acc);
	always @(posedge clk_sys) begin
		reg signed [11:0] x;
		reg signed [11:0] y;

		if (reset || !mouse_ena) begin
			mouse_toggle <= ps2_mouse[24];
			mouse_left <= 1'b0;
			mouse_middle <= 1'b0;
			mouse_right <= 1'b0;
			mouse_x_acc <= '0;
			mouse_y_acc <= '0;
		end else begin
			x = {mouse_x_acc[10],mouse_x_acc};
			y = {mouse_y_acc[10],mouse_y_acc};

			if (pad_latch) begin
				x = x - $signed({{2{mouse_x[9]}},mouse_x});
				y = y - $signed({{2{mouse_y[9]}},mouse_y});
			end

			if (ps2_mouse[24] != mouse_toggle) begin
				mouse_toggle <= ps2_mouse[24];
				mouse_left <= ps2_mouse[0];
				mouse_middle <= ps2_mouse[2];
				mouse_right <= ps2_mouse[1];
				x = x + $signed({mouse_dx[10],mouse_dx});
				y = y - $signed({mouse_dy[10],mouse_dy});
			end

			mouse_x_acc <= mouse_limit(x);
			mouse_y_acc <= mouse_limit(y);
		end
	end
	
	wire [31:0] mouse_data = {
		8'h49,
		mouse_left,
		mouse_middle,
		mouse_right,
		1'b0,
		mouse_y[9:0],
		mouse_x[9:0]
	};
	
	wire [87:0] mouse_data_p = {
		mouse_data,
		56'hFFFFFFFFFFFFFF
	};
	
	wire [87:0] pad_data = {
		{pad1_sel == 3'd0 ? joy0_data : 16'hFFFF,
		 pad2_eff == 3'd0 ? joy1_data : 16'hFFFF},
		56'hFFFFFFFFFFFFFF
	};
	
	wire [71:0] stick0_data = {
		8'h01,
		8'h7B,
		8'h08,
		stick0_x,
		2'b00,
		stick0_y,
		2'b00,
		stick0_z,
		4'h2,
		{joystick_0[11], joystick_0[4], joystick_0[5], joystick_0[6], joystick_0[3], joystick_0[2], joystick_0[0], joystick_0[1]},
		{joystick_0[7], joystick_0[8], joystick_0[10], joystick_0[9], 4'b0000}
	};
	wire [71:0] stick1_data = {
		8'h01,
		8'h7B,
		8'h08,
		stick1_x,
		2'b00,
		stick1_y,
		2'b00,
		stick1_z,
		4'h2,
		{joystick_1[11], joystick_1[4], joystick_1[5], joystick_1[6], joystick_1[3], joystick_1[2], joystick_1[0], joystick_1[1]},
		{joystick_1[7], joystick_1[8], joystick_1[10], joystick_1[9], 4'b0000}
	};
	wire [87:0] stick0_data_p = {
		stick0_data,
		16'hFFFF
	};
	wire [87:0] pad1_mouse_data = {
		joy0_data,
		mouse_data,
		40'hFFFFFFFFFF
	};
	wire [87:0] pad1_stick_data = {joy0_data, stick1_data};
	
	wire [87:0] PAD12_DATA = 
		(pad2_eff == 3'd1) ? pad1_mouse_data :
		(pad2_eff == 3'd2) ? pad1_stick_data :
		(pad1_sel == 3'd1) ? mouse_data_p :
		(pad1_sel == 3'd2) ? stick0_data_p :
		pad_data;
	
	HPS2PAD pad
	(
		.RST_N(~reset),
		.CLK(clk_sys),
		
		.CE(CE_R),
		
		.PBDIN(PBDIN),
		.PBDOUT(PBDOUT),
		.PBCLK(PBCLK),
		
		.EXPBDIN(1'b1),
		.EXPBDOUT(),
		.PAD_LATCH(pad_latch),
	
		.PAD_DATA(PAD12_DATA)
	);
	
	
	wire [31:0] sdr_dout;
	sdram sdram1
	(
		.SDRAM_CLK(SDRAM_CLK),
		.SDRAM_A(SDRAM_A),
		.SDRAM_BA(SDRAM_BA),
		.SDRAM_DQ(SDRAM_DQ),
		.SDRAM_DQML(SDRAM_DQML),
		.SDRAM_DQMH(SDRAM_DQMH),
		.SDRAM_nCS(SDRAM_nCS),
		.SDRAM_nWE(SDRAM_nWE),
		.SDRAM_nRAS(SDRAM_nRAS),
		.SDRAM_nCAS(SDRAM_nCAS),
		.SDRAM_CKE(SDRAM_CKE),
		
		.clk(clk_mem),
		.init(status[0]),
		.sync(MCLK_CE),
	
		.addr({2'b00,~LRAS3_N,LA[19:2]}),
		.din  (RAM_DO),
		.dout(sdr_dout),
		.we  ({~LWE_N,~RWE_N}),
		.ras(!LRAS2_N || !LRAS3_N || !RRAS2_N || !RRAS3_N),
		.code({3'b000,RCODE[0]} | LCODE),
		
		.rfs(!LRAS0_N || !RRAS0_N)
	);
	

	bit  [31: 0] VRAM_Q;
	bit          VRAM_LRDY,VRAM_RRDY;
	bit  [31: 0] vram_bldata;
	
	P3DO_VRAM #(`USE_BRAM_BLOCKS_FOR_VRAM) vram_l
	(
		.CLK(clk_sys),
		.CLK_MEM(clk_mem),
		.RST_N(~reset),
		
		.A(LA[19:2]),
		.D(RAM_DO[31:16]),
		.Q(VRAM_Q[31:16]),
		.RAS_N(LRAS0_N),
		.CAS_N(LCAS_N),
		.WE_N(LWE_N),
		.OE_N(LOE_N),
		.DSF1(LDSF),
		
		.SC(LSC),
		.SE_N(0),
		.SQ(VRAM_SQ[31:16]),
		.QSF(LQSF),
		
		.RDY(VRAM_LRDY),
		
		.EQ(ddr_do[31:16]),
		.ESADDR(ddr_bladdr),
		.ESDATA(vram_bldata),
		.ESWR(ddr_blwr),
		.ESRD(ddr_blrd),
		.ESQ({ddr_bout[63:48],ddr_bout[31:16]}),
		.ESTE(ddr_blte),
		
		.BRAM_OFFS(BRAM_OFFS)
	);
	
	bit  [31: 0] vram_brdata;
	P3DO_VRAM #(`USE_BRAM_BLOCKS_FOR_VRAM) vram_r
	(
		.CLK(clk_sys),
		.CLK_MEM(clk_mem),
		.RST_N(~reset),
		
		.A(RA[19:2]),
		.D(RAM_DO[15:0]),
		.Q(VRAM_Q[15:0]),
		.RAS_N(RRAS0_N),
		.CAS_N(RCAS_N),
		.WE_N(RWE_N),
		.OE_N(ROE_N),
		.DSF1(RDSF),
		
		.SC(RSC),
		.SE_N(0),
		.SQ(VRAM_SQ[15:0]),
		.QSF(RQSF),
		
		.RDY(VRAM_RRDY),
		
		.EQ(ddr_do[15:0]),
		.ESADDR(ddr_braddr),
		.ESDATA(vram_brdata),
		.ESWR(ddr_brwr),
		.ESRD(ddr_brrd),
		.ESQ({ddr_bout[47:32],ddr_bout[15:0]}),
		.ESTE(ddr_brte),
		
		.BRAM_OFFS(BRAM_OFFS)
	);
	
	assign RAM_DI = !LRAS0_N || !RRAS0_N ? VRAM_Q : sdr_dout;
	assign PDI = !SRAMR_N ? {24'h000000,NVRAM_Q} : ddr_io_do;

	
	//DDRAM
	wire [31: 0] ddr_io_do;
	wire         ddr_io_busy;
	wire [31: 0] ddr_do;
	wire         ddr_busy;
	wire [17: 0] ddr_bladdr,ddr_braddr;
	wire         ddr_blwr,ddr_brwr;
	wire         ddr_blrd,ddr_brrd;
	wire [63: 0] ddr_bin = {vram_bldata[31:16],vram_brdata[31:16],vram_bldata[15:0],vram_brdata[15:0]};
	wire [63: 0] ddr_bout;
	wire         ddr_blte,ddr_brte;
	wire         ddr_bbusy;
	wire         ddr_luse = ~((LA[19:2] >= (`USE_BRAM_BLOCKS_FOR_VRAM ? ({BRAM_OFFS+0,16'h0000}>>2) : ({BRAM_OFFS+4,16'h0000}>>2)) && LA[19:2] <= ({BRAM_OFFS+5,16'hBFFF}>>2)) || (LA[19:2] >= (20'hFC000>>2)));
	wire         ddr_ruse = ~((RA[19:2] >= (`USE_BRAM_BLOCKS_FOR_VRAM ? ({BRAM_OFFS+0,16'h0000}>>2) : ({BRAM_OFFS+4,16'h0000}>>2)) && RA[19:2] <= ({BRAM_OFFS+5,16'hBFFF}>>2)) || (RA[19:2] >= (20'hFC000>>2)));
	ddram ddram
	(
		.*,
		.clk(clk_mem),
		.rst(mem_rst),
	
		//
		.io_addr(bios_download || kanji_download ? {7'b0000001,kanji_download,ioctl_addr[19:2]} : {7'b0000001,ROM_SEL,PA[19:2]}),
		.io_din (bios_download || kanji_download ? {2{ioctl_data[7:0],ioctl_data[15:8]}} : RAM_DO),
		.io_we  (bios_download || kanji_download ? {~ioctl_addr[1],~ioctl_addr[1],ioctl_addr[1],ioctl_addr[1]}&{4{ioctl_wr}} : 4'b0000),
		.io_rd  (bios_download || kanji_download ? 1'b0 : ~ROMCS_N&MCLK_CE),
		.io_dout(ddr_io_do),
		.io_busy(ddr_io_busy),
		
		.sclk(SYS_CE_R),
		.laddr(LA[19:2]),
		.ldin (RAM_DO[31:16]),
		.lras (!LRAS0_N),
		.lwe  (ddr_luse ? ~LWE_N : '0),
		.lrd  (ddr_luse ? ~LOE_N : 0),
		.ldout(ddr_do[31:16]),
		.raddr(RA[19:2]),
		.rdin (RAM_DO[15:0]),
		.rras (!RRAS0_N),
		.rwe  (ddr_ruse ? ~RWE_N : '0),
		.rrd  (ddr_ruse ? ~ROE_N : 0),
		.rdout(ddr_do[15:0]),
		.busy(ddr_busy),
		
		.bladdr({9'b000000000,ddr_bladdr[17:0]}),
		.blwr  (ddr_blwr),
		.blrd  (ddr_blrd),
		.braddr({9'b000000000,ddr_braddr[17:0]}),
		.brwr  (ddr_brwr),
		.brrd  (ddr_brrd),
		.ba(),
		.bin(ddr_bin),
		.bout(ddr_bout),
		.blte(ddr_blte),
		.brte(ddr_brte),
		.bbusy(ddr_bbusy)
	);

	reg pause;
	
	always @(posedge clk_sys) begin
		bit cond;
		
		if (reset) begin
			pause <= 0;
		end else if (CE_F) begin
			cond = ddr_io_busy || ddr_busy || !VRAM_LRDY || !VRAM_RRDY || DBG_PAUSE;
			if (cond && !pause) begin
				pause <= 1;
			end
			if (!cond && pause) begin
				pause <= 0;
			end
		end
	end
	
	wire  [7:0] NVRAM_Q;
	dpram_dif #(15,8,14,16)	nvram
	(
		.clock(clk_sys),
		.address_a(PA[16:2]),
		.data_a(RAM_DO[7:0]),
		.wren_a(~SRAMW_N),
		.q_a(NVRAM_Q),

		.address_b({sd_lba[5:0],sd_buff_addr}),
		.data_b(sd_buff_dout),
		.wren_b(sd_buff_wr & sd_ack),
		.q_b(sd_buff_din)
	);
	
	/////////////////////////  STATE SAVE/LOAD  /////////////////////////////

	wire bk_save_write = ~SRAMW_N;
	reg bk_pending;

	always @(posedge clk_sys) begin
		if (bk_ena && !OSD_STATUS && bk_save_write)
			bk_pending <= 1'b1;
		else if (bk_state || !bk_ena || cdd_info_download)
			bk_pending <= 1'b0;
	end

	reg bk_ena = 0;
	reg old_downloading = 0;
	always @(posedge clk_sys) begin
		old_downloading <= save_download;
		if (~old_downloading & save_download) bk_ena <= 0;

		//Save file always mounted in the end of downloading state.
		if (save_download && img_mounted && !img_readonly) bk_ena <= 1;
	end

	wire bk_load    = status[12];
	wire bk_save    = status[13] | (bk_pending & OSD_STATUS & status[14]);
	reg  bk_loading = 0;
	reg  bk_state   = 0;
	always @(posedge clk_sys) begin
		reg old_load = 0, old_save = 0, old_ack;

		old_load <= bk_load & bk_ena;
		old_save <= bk_save & bk_ena;
		old_ack  <= sd_ack;

		if(sd_ack && !old_ack) {sd_rd, sd_wr} <= 0;

		if (!bk_state) begin
			if ((bk_load && !old_load) | (bk_save && !old_save)) begin
				bk_state <= 1;
				bk_loading <= bk_load;
				sd_lba <= 0;
				sd_rd <=  bk_load;
				sd_wr <= ~bk_load;
			end
			if (old_downloading && !bios_download && !kanji_download && bk_ena) begin
				bk_state <= 1;
				bk_loading <= 1;
				sd_lba <= 0;
				sd_rd <= 1;
				sd_wr <= 0;
			end
		end else begin
			if (old_ack && !sd_ack) begin
				if (sd_lba == 32'h3F) begin
					bk_loading <= 0;
					bk_state <= 0;
				end else begin
					sd_lba <= sd_lba + 1'd1;
					sd_rd  <=  bk_loading;
					sd_wr  <= ~bk_loading;
				end
			end
		end
	end
	

	////////////////////////////////////////////////////////////////
	wire PAL = 0;
	
	reg new_vmode;
	always @(posedge clk_sys) begin
		reg old_pal;
		int to;
		
		if(!reset) begin
			old_pal <= PAL;
			if(old_pal != PAL) to <= 5000000;
		end
		else to <= 5000000;
		
		if(to) begin
			to <= to - 1;
			if(to == 1) new_vmode <= ~new_vmode;
		end
	end
	
	
	wire [ 2: 0] scale = status[3:1];
	reg          forced_scandoubler_sync;
	reg  [ 2: 0] scale_sync;
	always @(posedge clk_vid) begin
		forced_scandoubler_sync <= forced_scandoubler;
		scale_sync <= scale;
	end
	wire [ 2: 0] sl = scale_sync ? scale_sync - 1'd1 : 3'd0;
	
	assign CLK_VIDEO = clk_vid;
	assign VGA_SL = {~INTERLACE,~INTERLACE} & sl[1:0];
	assign VGA_F1 = FIELD;
	
	wire vga_de;
	video_mixer #(.LINE_LENGTH(640+8), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
	(
		.*,
	
		.ce_pix(DCLK),	
		.scandoubler(~INTERLACE && (scale_sync || forced_scandoubler_sync)),
		.hq2x(scale_sync==1),	
		.freeze_sync(),
	
		.VGA_DE(vga_de),

		.R(R),
		.G(G),
		.B(B),
	
		// Positive pulses.
		.HSync(~HS_N),
		.VSync(~VS_N),
		.HBlank(~HBL_N),
		.VBlank(~VBL_N)
	);
	
	reg [ 1:0] ar;
	reg        vcrop_en;
	reg [ 3:0] vcopt;
	reg [ 1:0] vf_scale;
	reg        en216p;
	reg [ 4:0] voff;
	always @(posedge CLK_VIDEO) begin
		ar <= '0;//status[33:32];
		vcrop_en <= 0;//status[39];
		vcopt <= '0;//status[38:35];
		vf_scale <= '0;//status[41:40];
		en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler_sync && !scale_sync);
		voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
	end

	video_freak video_freak
	(
		.*,
		.VGA_DE_IN(vga_de),
		.ARX(12'd64),
		.ARY(12'd49),
		.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
		.CROP_OFF(voff),
		.SCALE(vf_scale)
	);


	//debug
	reg  [7:0] SCRN_EN = 8'b11111111;
	reg  [2:0] SND_EN = 3'b111;
	reg        DBG_PAUSE = 0;
	reg        DBG_BREAK = 0;
	reg        DBG_RUN = 0;
	
	reg  [7:0] DBG_EXT = '1;
	
	wire       pressed = ps2_key[9];
	wire [8:0] code    = ps2_key[8:0];
	always @(posedge clk_sys) begin
		reg old_state = 0;
	
		DBG_RUN <= 0;
		DBG_EXT[7:4] <= '0;
		
		old_state <= ps2_key[10];
		if((ps2_key[10] != old_state) && pressed) begin
			casex(code)
				'h005: begin SCRN_EN[0] <= ~SCRN_EN[0]; end 	// F1
				'h006: begin SCRN_EN[1] <= ~SCRN_EN[1]; end 	// F2
				'h004: begin SCRN_EN[2] <= ~SCRN_EN[2]; end 	// F3
				'h00C: begin SCRN_EN[3] <= ~SCRN_EN[3]; end 	// F4
				'h003: begin SCRN_EN[4] <= ~SCRN_EN[4]; end 	// F5
				'h00B: begin SCRN_EN[5] <= ~SCRN_EN[5]; end 	// F6
				'h083: begin SCRN_EN[6] <= ~SCRN_EN[6]; end 	// F7
				'h00A: begin SND_EN[0] <= ~SND_EN[0]; end 	// F8
				'h001: begin SND_EN[1] <= ~SND_EN[1]; end 	// F9
				'h009: begin SND_EN[2] <= ~SND_EN[2]; end 	// F10
				'h078: begin SCRN_EN <= '1; SND_EN <= '1; DBG_EXT <= '1; end 	// F11
`ifdef DEBUG
//				'h009: begin DBG_BREAK <= ~DBG_BREAK; end 	// F10
//				'h078: begin DBG_RUN <= 1; end 	// F11
				'h177: begin DBG_PAUSE <= ~DBG_PAUSE; end 	// Pause
				'h016: begin DBG_EXT[0] <= ~DBG_EXT[0]; end 	// 1
				'h01E: begin DBG_EXT[1] <= ~DBG_EXT[1]; end 	// 2
				'h026: begin DBG_EXT[2] <= ~DBG_EXT[2]; end 	// 3
				'h025: begin DBG_EXT[3] <= ~DBG_EXT[3]; end 	// 4
`endif
			endcase
		end
		
		if(pressed) begin
			casex(code)
`ifdef DEBUG
				'h02E: begin DBG_EXT[4] <= 1; end 	// 5
				'h036: begin DBG_EXT[5] <= 1; end 	// 6
				'h03D: begin DBG_EXT[6] <= 1; end 	// 7
				'h03E: begin DBG_EXT[7] <= 1; end 	// 8
`endif
				'h07B: begin DBG_EXT[6] <= 1; end 	// Num-
				'h079: begin DBG_EXT[7] <= 1; end 	// Num+
				default:;
			endcase
		end
	end

endmodule
