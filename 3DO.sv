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

	input         OSD_STATUS,
	
	output reg       dbg_error,
	output reg [11:0] DBG_WAIT_CNT
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
	
	wire [1:0] ar       = '0;//status[33:32];
	wire       vcrop_en = 0;//status[39];
	wire [3:0] vcopt    = '0;//status[38:35];
	reg        en216p;
	reg  [4:0] voff;
	always @(posedge CLK_VIDEO) begin
		en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
		voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
	end

	wire vga_de;
	video_freak video_freak
	(
		.*,
		.VGA_DE_IN(vga_de),
		.ARX(12'd64),
		.ARY(12'd49),
		.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
		.CROP_OFF(voff),
		.SCALE(status[41:40])
	);

	///////////////////////////////////////////////////
	
	// Status Bit Map:
	//             Upper                             Lower              
	// 0         1         2         3          4         5         6   
	// 01234567890123456789012345678901 23456789012345678901234567890123
	// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
	// XXXXXXXXXXX                                                      
	
	`include "build_id.v"
	localparam CONF_STR = {
		"3DO;;",
		"S0,CUEISO,Insert Disk;",
		"FS2,BIN,Load bios;",
		"-;",
		"OF,Load from CD,No,Yes;",

		"-;",
		"P1,Audio & Video;",
		"P1-;",
		"P1O4,Aspect Ratio,4:3,16:9;",
		"P1O5,320x224 Aspect,Original,Corrected;",
		"P1O13,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
		"P1-;",
		"P1O67,Composite Blend,Off,On,Adaptive;",
	
//		"P2,Input;",
//		"P2-;",

		"P3,Hardware;",
		"P3-;",
		"P3O8A,FB offset,H200000,H240000,H260000,H280000,H2A0000;",
		
		"-;",
		"R0,Reset;",
		"J1,A,B,C,P,X,R,L;",
		"V,v",`BUILD_DATE
	};

	wire [63:0] status;
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
	wire [15:0] sd_buff_din = '0;
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
		.status_menumask({1'b1,1'b1}),
	
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
//	wire cart_download = ioctl_download & (ioctl_index[5:2] == 4'b0000 && ioctl_index[1:0] == 2'h3);
	wire cdd_data_download = ioctl_download & (ioctl_index[5:2] == 4'b0010);
	wire cdd_info_download = ioctl_download & (ioctl_index[5:2] == 4'b0011);
	
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
	
	wire reset = RESET | status[0] | buttons[1] | bios_download;
	wire mem_rst = RESET | status[0] | buttons[1];
	
	wire [15:0] joy0_data = {1'b1, 2'b00, joystick_0[2], joystick_0[3], joystick_0[0], joystick_0[1], joystick_0[4], joystick_0[5], joystick_0[6], joystick_0[7], joystick_0[8], joystick_0[9], joystick_0[10], 2'b00};
	

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
	always @(posedge clk_sys) begin
		case (status[10:8])
			3'h0: BRAM_OFFS <= 4'h0;
			3'h1: BRAM_OFFS <= 4'h4;
			3'h2: BRAM_OFFS <= 4'h6;
			3'h3: BRAM_OFFS <= 4'h8;
			3'h4: BRAM_OFFS <= 4'hA;
		endcase
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
	
	reg POWER_ON;
	always @(posedge clk_sys) begin
		if (reset) POWER_ON <= 1;
		else if (CE_R) POWER_ON <= 0;
	end
	
	wire ACLK_CE;	//Audio clock
	CEGen AUD_CEGen
	(
		.CLK(clk_sys),
		.RST_N(1),
		.IN_CLK(in_clk),
		.OUT_CLK(16934400),
		.CE(ACLK_CE)
	);
	
	P3DO p3do
	(
		.RST_N(~reset),
		.CLK(clk_sys),
		.EN(1),
		.PAUSE(pause),
		
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
		
		.VCE_R(CE_R),
		.VCE_F(CE_F),
		.AD({R,G,B}),
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
	
		.DISCIN(status[15]),
		.EXT_BUS(EXT_BUS)
	);
	
	HPS2PAD pad0
	(
		.RST_N(~reset),
		.CLK(clk_sys),
		
		.CE(CE_R),
		
		.PBDIN(PBDIN),
		.PBDOUT(PBDOUT),
		.PBCLK(PBCLK),
		
		.EXPBDIN(1'b1),
		.EXPBDOUT(),
	
		.JOY(joy0_data)
	);
	
	wire [15:0] sdr1_dout;
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
		.wr  (!LRAS2_N || !LRAS3_N ? LCODE[0]                  : 1'b0),
		.rd  (!LRAS2_N || !LRAS3_N ? ~LCODE[0]                 : 1'b0),
		.we  (!LRAS2_N || !LRAS3_N ? ~LWE_N                    : 2'b00),
		.din  (RAM_DO[31:16]),
		.dout(sdr1_dout),
		
		.rfs(1'b0)
	);
	
	wire [15:0] sdr2_dout;
	sdram sdram2
	(
		.SDRAM_CLK(SDRAM2_CLK),
		.SDRAM_A(SDRAM2_A),
		.SDRAM_BA(SDRAM2_BA),
		.SDRAM_DQ(SDRAM2_DQ),
		.SDRAM_DQML(),
		.SDRAM_DQMH(),
		.SDRAM_nCS(SDRAM2_nCS),
		.SDRAM_nWE(SDRAM2_nWE),
		.SDRAM_nRAS(SDRAM2_nRAS),
		.SDRAM_nCAS(SDRAM2_nCAS),
		.SDRAM_CKE(),
		
		.clk(clk_mem),
		.init(status[0]),
		.sync(MCLK_CE),
	
		.addr({1'b0,~RRAS3_N,RA[19:11],1'b0,RA[10:2]}),
		.wr  (!RRAS2_N || !RRAS3_N ? RCODE[0]  : 1'b0),
		.rd  (!RRAS2_N || !RRAS3_N ? ~RCODE[0] : 1'b0),
		.we  (!RRAS2_N || !RRAS3_N ? ~RWE_N    : 2'b00),
		.din  (RAM_DO[15:0]),
		.dout(sdr2_dout),
		
		.rfs(1'b0)
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
	
	assign RAM_DI = !LRAS0_N || !RRAS0_N ? VRAM_Q : {sdr1_dout,sdr2_dout};
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
		.io_addr(bios_download ? {8'b00000001,ioctl_addr[19:2]} : {8'b00000001,PA[19:2]}),
		.io_din (bios_download ? {2{ioctl_data[7:0],ioctl_data[15:8]}} : RAM_DO),
		.io_we  (bios_download ? {~ioctl_addr[1],~ioctl_addr[1],ioctl_addr[1],ioctl_addr[1]}&{4{ioctl_wr}} : 4'b0000),
		.io_rd  (bios_download ? 1'b0 : ~ROMCS_N&MCLK_CE),
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
			
			if (pause) DBG_WAIT_CNT <= DBG_WAIT_CNT + 1'd1;
			else DBG_WAIT_CNT <= '0;
		end
	end
	
	wire  [7:0] NVRAM_Q;
	dpram #(15)	nvram
	(
		.clock(clk_sys),
		.address_a(PA[16:2]),
		.data_a(RAM_DO[7:0]),
		.wren_a(~SRAMW_N),
		.q_a(NVRAM_Q),

		.address_b('0),
		.wren_b(0)
	);
	

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
	
	assign VGA_F1 = FIELD;
	
	wire [2:0] scale = status[3:1];
	wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
	
	assign CLK_VIDEO = clk_sys;
	assign VGA_SL = {~INTERLACE,~INTERLACE} & sl[1:0];
	
	video_mixer #(.LINE_LENGTH(320+8), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
	(
		.*,
	
		.ce_pix(DCLK),	
		.scandoubler(~INTERLACE && (scale || forced_scandoubler)),
		.hq2x(scale==1),	
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
				default:;
			endcase
		end
	end

endmodule
