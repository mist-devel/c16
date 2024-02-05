//
// c16_mist.sv - C16 for the MiST
//
// https://github.com/mist-devel
// 
// Copyright (c) 2015 Till Harbaum <till@harbaum.org> 
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module c16_mist_top (
	input         CLOCK_27,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output        LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
	input         UART_RX,
	output        UART_TX

);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

// remove this if the 2nd chip is actually used
`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 0;
assign SDRAM2_DQMH = 0;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif

`include "build_id.v"

// -------------------------------------------------------------------------
// ------------------------------ user_io ----------------------------------
// -------------------------------------------------------------------------

// user_io implements a connection to the io controller and receives various
// kind of user input from there (keyboard, buttons, mouse). It is also used
// by the fake SD card to exchange data with the real sd card connected to the
// io controller

// the configuration string is returned to the io controller to allow
// it to control the menu on the OSD 
`include "build_id.v"
parameter CONF_STR = {
        "C16;PRGTAP;",
        "S0U,D64,Mount Disk;",
        "F,ROM,Load Kernal;",
        "T6,Play/Stop tape;",
        "O7,Tape sound,Off,On;",
        "O12,Scanlines,Off,25%,50%,75%;",
        "O3,Joysticks,Normal,Swapped;",
        "O4,Memory,64k,16k;",
        "O89,SID,Off,6581,8580;",
        "T5,Reset;",
        "V",`BUILD_DATE
};

localparam ROM_MEM_START = 25'h10000;
localparam TAP_MEM_START = 25'h20000;

reg uart_rxD;
reg uart_rxD2;
wire ear_input;
// UART_RX synchronizer
always @(posedge clk28) begin
        uart_rxD <= UART_RX;
        uart_rxD2 <= uart_rxD;
end

`ifdef USE_AUDIO_IN
reg ainD;
reg ainD2;
always @(posedge clk28) begin
        ainD <= AUDIO_IN;
        ainD2 <= ainD;
end
assign ear_input = ainD2;
`else
assign ear_input = uart_rxD2;
`endif

assign UART_TX = ~cass_motor;

// the status register is controlled by the on screen display (OSD)
wire [31:0] status;
wire tv15khz;
wire ypbpr;
wire no_csync;
wire [1:0] scanlines = status[2:1];
wire joystick_swap = status[3];
wire memory_16k = status[4];
wire osd_reset = status[5];
wire tap_play = status[6];
wire tap_sound = status[7];
wire [1:0] sid_type = status[9:8];
wire [1:0] buttons;

wire [7:0] js0, js1;
wire [7:0] jsA = joystick_swap?js1:js0;
wire [7:0] jsB = joystick_swap?js0:js1;

wire ps2_kbd_clk, ps2_kbd_data;
wire ps2_mouse_clk, ps2_mouse_data;

// -------------------------------------------------------------------------
// ---------------- interface to the external sdram ------------------------
// -------------------------------------------------------------------------

// SDRAM control signals
assign SDRAM_CKE = 1'b1;

// ram access signals from c16
wire c16_rom_access = (~c16_basic_sel | ~c16_kernal_sel) && c16_rw;
wire c16_basic_sel;
wire c16_kernal_sel;
wire [13:0] c16_rom_addr;
wire [3:0] c16_rom_sel;
reg [1:0] c16_rom_sel_mux;

always @(*) begin
	casex ({ c16_basic_sel, c16_rom_sel })
		'b1_00XX: c16_rom_sel_mux <= 2'b00; // Kernal
		'b1_10XX: c16_rom_sel_mux <= 2'b11; // Function HIGH
		'b0_XX00: c16_rom_sel_mux <= 2'b01; // BASIC
		'b0_XX10: c16_rom_sel_mux <= 2'b10; // Function LOW
		default : c16_rom_sel_mux <= 2'b00; // CARTRIDGE - not supported now
	endcase
end

wire [15:0] c16_sdram_addr = c16_rom_access ? { c16_rom_sel_mux, c16_rom_addr } : { c16_a_hi, c16_a_low };
wire [7:0] c16_sdram_data = c16_dout;
wire c16_sdram_wr = !c16_cas && !c16_rw;
wire c16_sdram_oe = (!c16_cas && c16_rw) || c16_rom_access;

// ram access signals from io controller
// ioctl_sdram_write
// ioctl_sdram_addr
// ioctl_sdram_data

// multiplex c16 and ioctl signals
wire [24:0] mux_sdram_addr = clkref ? c16_sdram_addr : (tap_sdram_oe ? tap_play_addr : ioctl_sdram_addr);
wire [ 7:0] mux_sdram_data = clkref ? c16_sdram_data : ioctl_sdram_data;
wire mux_sdram_wr = clkref ? c16_sdram_wr : ioctl_sdram_write;
wire mux_sdram_oe = clkref ? c16_sdram_oe : tap_sdram_oe;

wire [15:0] sdram_din = { mux_sdram_data, mux_sdram_data };
wire [14:0] sdram_addr_64k = mux_sdram_addr[15:1];   // 64k mapping
wire [14:0] sdram_addr_16k = { 1'b0, mux_sdram_addr[13:7], 1'b0, mux_sdram_addr[6:1] };   // 16k
wire [14:0] sdram_addr_c16ram = memory_16k?sdram_addr_16k:sdram_addr_64k;

reg  [23:0] sdram_addr;
always @(*) begin
	casex ({ clkref, c16_rom_access, prg_download, tap_sdram_oe })
		'b0X00: sdram_addr = ioctl_sdram_addr[24:1];
		'b0X01: sdram_addr = tap_play_addr[24:1];
		'b0X1X: sdram_addr = { 9'd0, sdram_addr_c16ram };
		'b10XX: sdram_addr = { 9'd0, sdram_addr_c16ram };
		'b11XX: sdram_addr = { 8'd0,1'b1, c16_rom_sel_mux, c16_rom_addr[13:1] };
	endcase
end

wire sdram_wr = mux_sdram_wr;
wire sdram_oe = mux_sdram_oe;
wire [1:0] sdram_ds = { mux_sdram_addr[0], !mux_sdram_addr[0] }; 

wire [15:0] sdram_dout;
wire [7:0] c16_din = zp_overwrite?zp_ovl_dout:
	(c16_a_low[0]?sdram_dout[15:8]:sdram_dout[7:0]);

assign SDRAM_CLK = clk28;

// synchronize sdram state machine with the ras/cas phases of the c16
reg last_ras;
reg [3:0] clkdiv;
wire clkref = clkdiv[3];
always @(posedge clk28) begin	
	if(!c16_ras && last_ras) begin
		clkdiv <= 4'd0;
		last_ras <= c16_ras;
	end else
		clkdiv <= clkdiv + 4'd1;
end	

// latch/demultiplex dram address
reg [7:0] c16_a_low;
reg [7:0] c16_a_hi;

always @(posedge clk28) begin
	reg c16_rasD, c16_casD;
	c16_rasD <= c16_ras;
	c16_casD <= c16_cas;
	if (c16_rasD & ~c16_ras) c16_a_low <= c16_a;
	if (c16_casD & ~c16_cas) c16_a_hi  <= c16_a;
end

sdram sdram (
   // interface to the MT48LC16M16 chip
   .sd_data        ( SDRAM_DQ                  ),
   .sd_addr        ( SDRAM_A                   ),
   .sd_dqm         ( {SDRAM_DQMH, SDRAM_DQML}  ),
   .sd_cs          ( SDRAM_nCS                 ),
   .sd_ba          ( SDRAM_BA                  ),
   .sd_we          ( SDRAM_nWE                 ),
   .sd_ras         ( SDRAM_nRAS                ),
   .sd_cas         ( SDRAM_nCAS                ),

   // system interface
   .clk            ( clk28                     ),
   .clkref         ( clkref                    ),
   .init           ( !pll_locked               ),

   // cpu interface
   .din            ( sdram_din                 ),
   .addr           ( sdram_addr                ),
   .we             ( sdram_wr                  ),
   .oe             ( sdram_oe                  ),
   .ds             ( sdram_ds                  ),
   .dout           ( sdram_dout                )
);


// ---------------------------------------------------------------------------------
// -------------------------------------- reset ------------------------------------
// ---------------------------------------------------------------------------------

reg last_mem16k;
reg [31:0] reset_cnt;
wire reset = (reset_cnt != 0);
always @(posedge clk28, negedge pll_locked) begin
	if (!pll_locked) begin
		// long reset on startup 
		reset_cnt <= 32'd28000000;
	end
	else begin
		last_mem16k <= memory_16k;
		// long reset when io controller reboots
		if(status[0])
			reset_cnt <= 32'd28000000;
		// short reset on reset button, reset osd or when io controller is
		// done downloading or when memory mapping changes
		else if(buttons[1] || osd_reset || rom_download || (memory_16k != last_mem16k))
			reset_cnt <= 32'd65536;
		else if(reset_cnt != 0)
			reset_cnt <= reset_cnt - 32'd1;
	end
end

// signals to connect io controller with virtual sd card
wire [31:0] sd_lba;
wire sd_rd;
wire sd_wr;
wire sd_ack;
wire sd_ack_conf;
wire sd_conf;
wire sd_sdhc = 1'b1;
wire [7:0] sd_dout;
wire sd_dout_strobe;
wire [7:0] sd_din;
wire sd_din_strobe;
wire img_mounted;
wire [31:0] img_size;
wire [8:0] sd_buff_addr;
`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_rdata;
wire  [7:0] i2c_wdata;
wire        i2c_ack;
wire        i2c_end;
`endif

// include user_io module for arm controller communication
user_io #(.STRLEN($size(CONF_STR)>>3), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io (
	.conf_str       ( CONF_STR       ),

	.clk_sys        ( clk28          ),
	.clk_sd         ( clk32          ),

	.SPI_CLK        ( SPI_SCK        ),
	.SPI_SS_IO      ( CONF_DATA0     ),
	.SPI_MISO       ( SPI_DO         ),
	.SPI_MOSI       ( SPI_DI         ),

	.scandoubler_disable ( tv15khz   ),
	.ypbpr          ( ypbpr          ),
	.no_csync       ( no_csync       ),
	.buttons        ( buttons        ),

	.joystick_0     ( js0            ),
	.joystick_1     ( js1            ),
		
	// ps2 interface
	.ps2_kbd_clk    ( ps2_kbd_clk    ),
	.ps2_kbd_data   ( ps2_kbd_data   ),
	.ps2_mouse_clk  ( ps2_mouse_clk  ),
	.ps2_mouse_data ( ps2_mouse_data ),


	.status         ( status         ),
`ifdef USE_HDMI
	.i2c_start      ( i2c_start      ),
	.i2c_read       ( i2c_read       ),
	.i2c_addr       ( i2c_addr       ),
	.i2c_subaddr    ( i2c_subaddr    ),
	.i2c_dout       ( i2c_wdata      ),
	.i2c_din        ( i2c_rdata      ),
	.i2c_ack        ( i2c_ack        ),
	.i2c_end        ( i2c_end        ),
`endif
	.sd_lba         ( sd_lba         ),
	.sd_rd          ( sd_rd          ),
	.sd_wr          ( sd_wr          ),
	.sd_ack         ( sd_ack         ),
	.sd_ack_conf    ( sd_ack_conf    ),
	.sd_conf        ( sd_conf        ),
	.sd_sdhc        ( sd_sdhc        ),
	.sd_dout        ( sd_dout        ),
	.sd_dout_strobe ( sd_dout_strobe ),
	.sd_din         ( sd_din         ),
	.sd_din_strobe  ( sd_din_strobe  ),
	.sd_buff_addr   ( sd_buff_addr   ),
	.img_mounted    ( img_mounted    ),
	.img_size       ( img_size       )
);

// ---------------------------------------------------------------------------------
// ------------------------------ prg memory injection -----------------------------
// ---------------------------------------------------------------------------------

wire ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_data;
wire [7:0] ioctl_index;
wire ioctl_downloading;

wire rom_download = ioctl_downloading && ((ioctl_index == 8'h00) || (ioctl_index == 8'h03));
wire prg_download = ioctl_downloading && (ioctl_index == 8'h01);
wire tap_download = ioctl_downloading && (ioctl_index == 8'h41);

wire c16_wait = rom_download | prg_download;

data_io data_io (
	.clk_sys        ( clk28 ),
	// SPI interface
	.SPI_SCK        ( SPI_SCK ),
	.SPI_SS2        ( SPI_SS2 ),
	.SPI_DI         ( SPI_DI  ),

	// ram interface
	.ioctl_download ( ioctl_downloading ),
	.ioctl_index    ( ioctl_index ),
	.ioctl_wr       ( ioctl_wr ),
	.ioctl_addr     ( ioctl_addr ),
	.ioctl_dout     ( ioctl_data )
);

// magic zero page shadow registers to allow the injector to set the
// basic program end pointers automagically after injection
reg [15:0] reg_2d;
reg [15:0] reg_2f;
reg [15:0] reg_31;
reg [15:0] reg_9d;

wire zp_2d_sel = c16_sdram_addr == 16'h002d;
wire zp_2e_sel = c16_sdram_addr == 16'h002e;
wire zp_2f_sel = c16_sdram_addr == 16'h002f;
wire zp_30_sel = c16_sdram_addr == 16'h0030;
wire zp_31_sel = c16_sdram_addr == 16'h0031;
wire zp_32_sel = c16_sdram_addr == 16'h0032;
wire zp_9d_sel = c16_sdram_addr == 16'h009d;
wire zp_9e_sel = c16_sdram_addr == 16'h009e;

wire zp_overwrite = !c16_rom_access && (
	zp_2d_sel || zp_2e_sel || zp_2f_sel || zp_30_sel ||
	zp_31_sel || zp_32_sel || zp_9d_sel || zp_9e_sel);

reg zp_cas_delay, zp_sel;
reg zp_dl_delay, zp_dl;

always @(posedge clk28) begin
	// write pulse one cycle after falling edge of cas to make sure address
	// is stable
	zp_cas_delay <= c16_cas;
	zp_sel <= !c16_cas && zp_cas_delay;
	zp_dl_delay <= prg_download;
	zp_dl <= !prg_download && zp_dl_delay;

	if(zp_dl) begin
		// registers are automatically adjusted at the end of the
		// download/injection
		// the registers to be set have been taken from the vice emulator
		reg_2d <= ioctl_sdram_addr[15:0] + 16'd1;
		reg_2f <= ioctl_sdram_addr[15:0] + 16'd1;
		reg_31 <= ioctl_sdram_addr[15:0] + 16'd1;
		reg_9d <= ioctl_sdram_addr[15:0] + 16'd1;
	end else	if(zp_sel && !c16_rw) begin
		// cpu writes registers
		if(zp_2d_sel) reg_2d[ 7:0] <= c16_dout;
		if(zp_2e_sel) reg_2d[15:8] <= c16_dout;
		if(zp_2f_sel) reg_2f[ 7:0] <= c16_dout;
		if(zp_30_sel) reg_2f[15:8] <= c16_dout;
		if(zp_31_sel) reg_31[ 7:0] <= c16_dout;
		if(zp_32_sel) reg_31[15:8] <= c16_dout;
		if(zp_9d_sel) reg_9d[ 7:0] <= c16_dout;
		if(zp_9e_sel) reg_9d[15:8] <= c16_dout;
	end
end
	
wire [7:0] zp_ovl_dout =
	zp_2d_sel?reg_2d[7:0]:zp_2e_sel?reg_2d[15:8]:
	zp_2f_sel?reg_2f[7:0]:zp_30_sel?reg_2f[15:8]:
	zp_31_sel?reg_31[7:0]:zp_32_sel?reg_31[15:8]:
	zp_9d_sel?reg_9d[7:0]:zp_9e_sel?reg_9d[15:8]:
	8'hff;
	
reg        ioctl_ram_wr;
reg [ 7:0] ioctl_ram_data;
reg [24:0] ioctl_sdram_addr;
reg [ 7:0] ioctl_sdram_data;
reg        ioctl_sdram_write;

// address starts counting with 0
always @(posedge clk28) begin
	reg last_clkref;

	last_clkref <= clkref;

	// C16 time slice - clkref=1, IO controller - clkref=0
	if (~clkref & last_clkref) begin
		ioctl_sdram_write <= ioctl_ram_wr;
		ioctl_ram_wr <= 0;
		if (ioctl_ram_wr) ioctl_sdram_data <= ioctl_ram_data;
	end
	if (clkref & ~last_clkref) begin
		if (ioctl_sdram_write) ioctl_sdram_addr <= ioctl_sdram_addr + 1'd1;
		ioctl_sdram_write <= 0;
	end

	// data io has a byte for us
	if(ioctl_wr) begin
		if (prg_download) begin
			// the address taken from the first to bytes of a prg file tell
			// us where the file is to go in memory
			if(ioctl_addr == 0) ioctl_sdram_addr[7:0] <= ioctl_data;
			else if (ioctl_addr == 25'h1) ioctl_sdram_addr[24:8] <= { 9'b0, ioctl_data };
			else 
				ioctl_ram_wr <= 1'b1;
		end else if (tap_download) begin
			if(ioctl_addr == 0) ioctl_sdram_addr <= TAP_MEM_START;
			ioctl_ram_wr <= 1'b1;
		end else if (rom_download) begin
			if((ioctl_index == 8'h0 && ioctl_addr == 25'h4000) || (ioctl_index == 8'h3 && ioctl_addr == 0)) ioctl_sdram_addr <= ROM_MEM_START;
			if((ioctl_index == 8'h0 && ioctl_addr[16:14] != 0) || ioctl_index == 8'h3) ioctl_ram_wr <= 1'b1;
		end
		// io controller sent a new byte. Store it until it can be
		// saved in RAM
		ioctl_ram_data <= ioctl_data;
	end

end

// ---------------------------------------------------------------------------------
// -------------------------------- TAP playback -----------------------------------
// ---------------------------------------------------------------------------------

reg [24:0] tap_play_addr;
reg [24:0] tap_last_addr;
reg  [7:0] tap_data_in;
reg        tap_reset;
reg        tap_wrreq;
reg        tap_wrfull;
reg  [1:0] tap_version;
reg        tap_sdram_oe;
wire       cass_read;
wire       cass_write;
wire       cass_motor;
wire       cass_sense;

always @(posedge clk28) begin
	reg clkref_D;

    if (reset) begin
        tap_play_addr <= TAP_MEM_START;
        tap_last_addr <= TAP_MEM_START;
        tap_sdram_oe <= 0;
        tap_reset <= 1;
    end else begin
        tap_reset <= 0;
        if (tap_download) begin
            tap_play_addr <= TAP_MEM_START;
            tap_last_addr <= ioctl_sdram_addr;
            tap_reset <= 1;
            if (ioctl_sdram_addr == (TAP_MEM_START + 25'h0C) && ioctl_wr) begin
                tap_version <= ioctl_data[1:0];
            end
        end
        clkref_D <= clkref;
        tap_wrreq <= 0;
        if (clkref_D && !clkref && !ioctl_downloading && tap_play_addr != tap_last_addr && !tap_wrfull) tap_sdram_oe <= 1;
        if (clkref && !clkref_D && tap_sdram_oe) begin
            tap_wrreq <= 1;
            tap_data_in <= tap_play_addr[0] ? sdram_dout[15:8]:sdram_dout[7:0];
            tap_sdram_oe <= 0;
            tap_play_addr <= tap_play_addr + 1'd1;
        end
    end
end

c1530 c1530
(
    .clk32(clk28),
    .restart_tape(tap_reset),
    .wav_mode(0),
    .tap_version(tap_version),
    .host_tap_in(tap_data_in),
    .host_tap_wrreq(tap_wrreq),
    .tap_fifo_wrfull(tap_wrfull),
    .tap_fifo_error(),
    .cass_read(cass_read),
    .cass_write(cass_write),
    .cass_motor(cass_motor),
    .cass_sense(cass_sense),
    .osd_play_stop_toggle(tap_play),
    .ear_input(ear_input)
);

// ---------------------------------------------------------------------------------
// ---------------------------------- video output ---------------------------------
// ---------------------------------------------------------------------------------
wire hs, vs;

mist_video #(.COLOR_DEPTH(4), .OSD_COLOR(3'd5), .SD_HCNT_WIDTH(10), .OSD_AUTO_CE(0), .BIG_OSD(BIG_OSD), .OUT_COLOR_DEPTH(VGA_BITS)) mist_video (
	.clk_sys     ( clk28      ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( scanlines  ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 1'b0       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( tv15khz ),
	// disable csync without scandoubler
	.no_csync    ( no_csync   ),
	// YPbPr always uses composite sync
	.ypbpr       ( ypbpr      ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( c16_r      ),
	.G           ( c16_g      ),
	.B           ( c16_b      ),

	.HSync       ( c16_hs     ),
	.VSync       ( ~c16_vs    ),

	// MiST video output signals
	.VGA_R       ( VGA_R      ),
	.VGA_G       ( VGA_G      ),
	.VGA_B       ( VGA_B      ),
	.VGA_VS      ( vs         ),
	.VGA_HS      ( hs         )
);

// Use TED generated csync @15kHz
assign VGA_HS = (~no_csync & tv15khz & ~ypbpr) ? c16_cs : hs;
assign VGA_VS = (~no_csync & tv15khz & ~ypbpr) ? 1'b1 : vs;

`ifdef USE_HDMI
i2c_master #(28_000_000) i2c_master (
	.CLK         (clk28),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_wdata),
	.I2C_RDATA   (i2c_rdata),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

mist_video #(.COLOR_DEPTH(4), .OSD_COLOR(3'd5), .SD_HCNT_WIDTH(10), .OSD_AUTO_CE(0), .OUT_COLOR_DEPTH(8), .USE_BLANKS(1'b1), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1'b1)) hdmi_video (
	.clk_sys     ( clk28      ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( scanlines  ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 1'b0       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( 1'b0 ),
	// disable csync without scandoubler
	.no_csync    ( 1'b1       ),
	// YPbPr always uses composite sync
	.ypbpr       ( 1'b0       ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( c16_r      ),
	.G           ( c16_g      ),
	.B           ( c16_b      ),

	.HSync       ( c16_hs     ),
	.VSync       ( ~c16_vs    ),
	.HBlank      ( c16_hb     ),
	.VBlank      ( c16_vb     ),

	// MiST video output signals
	.VGA_R       ( HDMI_R     ),
	.VGA_G       ( HDMI_G     ),
	.VGA_B       ( HDMI_B     ),
	.VGA_VS      ( HDMI_VS    ),
	.VGA_HS      ( HDMI_HS    ),
	.VGA_DE      ( HDMI_DE    )
);

assign HDMI_PCLK = clk28;

`endif

// ---------------------------------------------------------------------------------
// ------------------------------------ c16 core -----------------------------------
// ---------------------------------------------------------------------------------

// c16 generated video signals
wire c16_hs, c16_vs, c16_cs;
wire c16_hb, c16_vb;
wire [3:0] c16_r;
wire [3:0] c16_g;
wire [3:0] c16_b;
wire c16_pal;

// c16 generated ram access signals
wire c16_ras;
wire c16_cas;
wire c16_rw;
wire [7:0] c16_a;
wire [7:0] c16_dout;

reg kernal_dl_wr, basic_dl_wr, c1541_dl_wr;
reg [7:0] rom_dl_data;
reg [13:0] rom_dl_addr;

wire ioctl_rom_wr = rom_download && ioctl_wr;

always @(negedge clk28) begin
	reg last_ioctl_rom_wr;
	last_ioctl_rom_wr <= ioctl_rom_wr;
	if(ioctl_rom_wr && !last_ioctl_rom_wr) begin
		rom_dl_data  <= ioctl_data;
		rom_dl_addr  <= ioctl_addr[13:0];
		c1541_dl_wr  <= ioctl_addr[16:14] == 3'd0 && ioctl_index == 8'h0;
		kernal_dl_wr <= ioctl_addr[16:14] == 3'd1 || ioctl_index == 8'h3;
		basic_dl_wr  <= ioctl_addr[16:14] == 3'd2 && ioctl_index == 8'h0;
	end else
		{ kernal_dl_wr, basic_dl_wr, c1541_dl_wr } <= 0;
end

wire audio_l_out, audio_r_out;
wire [17:0] sid_audio;
wire [17:0] audio_data_l = sid_audio + { audio_l_out, tap_sound & ~cass_read, 14'd0 };
wire [17:0] audio_data_r = sid_audio + { audio_r_out, tap_sound & ~cass_read, 14'd0 };

sigma_delta_dac dac (
	.clk      ( clk28),
	.ldatasum ( audio_data_l[17:3] ),
	.rdatasum ( audio_data_r[17:3] ),
	.aleft    ( AUDIO_L ),
	.aright   ( AUDIO_R )
);

wire [31:0] clk_rate = c16_pal ? 32'd28_375_168 : 32'd28_636_352;

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk28),
	.clk_rate(clk_rate),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan(audio_data_l[17:2]),
	.right_chan(audio_data_r[17:2])
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk28) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif (
	.clk_i(clk28),
	.rst_i(1'b0),
	.clk_rate_i(clk_rate),
	.spdif_o(SPDIF),
	.sample_i({audio_data_r[17:2], audio_data_l[17:2]})
);
`endif

// include the c16 itself
C16 #(.INTERNAL_ROM(0)) c16 (
	.CLK28   ( clk28 ),
	.RESET   ( reset ),
	.WAIT    ( c16_wait ),
	.HSYNC   ( c16_hs ),
	.VSYNC   ( c16_vs ),
	.CSYNC   ( c16_cs ),
	.HBLANK  ( c16_hb ),
	.VBLANK  ( c16_vb ),
	.RED     ( c16_r ),
	.GREEN   ( c16_g ),
	.BLUE    ( c16_b ),
	
	.RAS     ( c16_ras ),
	.CAS     ( c16_cas ),
	.RW      ( c16_rw ),
	.A       ( c16_a ),
	.DOUT    ( c16_dout ),
	.DIN     ( c16_din ),

	.CS0     ( c16_basic_sel  ),
	.CS1     ( c16_kernal_sel ),
	.ROM_ADDR( c16_rom_addr   ),
	.ROM_SEL ( c16_rom_sel    ),

	.JOY0    ( jsB[4:0] ),
	.JOY1    ( jsA[4:0] ),
	
	.PS2DAT  ( ps2_kbd_data ),
	.PS2CLK  ( ps2_kbd_clk  ),

	.dl_addr         ( rom_dl_addr ),
	.dl_data         ( rom_dl_data ),
	.kernal_dl_write ( kernal_dl_wr   ),
	.basic_dl_write  ( basic_dl_wr    ),
	
	.IEC_DATAOUT ( c16_iec_data_o ),
	.IEC_DATAIN  ( c16_iec_data_i ),
	.IEC_CLKOUT  ( c16_iec_clk_o ),
	.IEC_CLKIN   ( c16_iec_clk_i ),
	.IEC_ATNOUT  ( c16_iec_atn_o ),
	.IEC_RESET   ( ),

	.CASS_READ   ( cass_read  ),
	.CASS_WRITE  ( cass_write ),
	.CASS_MOTOR  ( cass_motor ),
	.CASS_SENSE  ( cass_sense ),

	.SID_TYPE    ( sid_type    ),
	.SID_AUDIO   ( sid_audio   ),
	.AUDIO_L     ( audio_l_out ),
	.AUDIO_R     ( audio_r_out ),

	.PAL         ( c16_pal ),
	
	.RS232_TX    (),
	.RGBS        ()
);


// ---------------------------------------------------------------------------------
// ------------------------------- clock generation --------------------------------
// ---------------------------------------------------------------------------------

// the FPGATED uses two different clocks for NTSC and PAL mode.
// Switching the clocks may crash the system. We might need to force a reset it.
wire pll_locked = pll_c16_locked;
wire ntsc = ~c16_pal;

// A PLL to derive the system clock from the MiSTs 27MHz
wire pll_c1541_locked, clk32;
pll_c1541 pll_c1541 (
    .inclk0 ( CLOCK_27          ),
    .c0     ( clk32             ),
    .locked ( pll_c1541_locked  )
);

wire pll_c16_locked, clk28;
pll_c16 pll_c16 (
    .inclk0(CLOCK_27),
    .c0(clk28),
    .areset(pll_areset),
    .scanclk(pll_scanclk),
    .scandata(pll_scandata),
    .scanclkena(pll_scanclkena),
    .configupdate(pll_configupdate),
    .scandataout(pll_scandataout),
    .scandone(pll_scandone),
    .locked(pll_c16_locked)
);

wire       pll_reconfig_busy;
wire       pll_areset;
wire       pll_configupdate;
wire       pll_scanclk;
wire       pll_scanclkena;
wire       pll_scandata;
wire       pll_scandataout;
wire       pll_scandone;
reg        pll_reconfig_reset;
wire [7:0] pll_rom_address;
wire       pll_rom_q;
reg        pll_write_from_rom;
wire       pll_write_rom_ena;
reg        pll_reconfig;
wire       q_reconfig_ntsc;
wire       q_reconfig_pal;

rom_reconfig_pal rom_reconfig_pal
(
    .address(pll_rom_address),
    .clock(clk32),
    .rden(pll_write_rom_ena),
    .q(q_reconfig_pal)
);

rom_reconfig_ntsc rom_reconfig_ntsc
(
    .address(pll_rom_address),
    .clock(clk32),
    .rden(pll_write_rom_ena),
    .q(q_reconfig_ntsc)
);

assign pll_rom_q = ntsc ? q_reconfig_ntsc : q_reconfig_pal;

pll_reconfig pll_reconfig_inst
(
    .busy(pll_reconfig_busy),
    .clock(clk32),
    .counter_param(0),
    .counter_type(0),
    .data_in(0),
    .pll_areset(pll_areset),
    .pll_areset_in(0),
    .pll_configupdate(pll_configupdate),
    .pll_scanclk(pll_scanclk),
    .pll_scanclkena(pll_scanclkena),
    .pll_scandata(pll_scandata),
    .pll_scandataout(pll_scandataout),
    .pll_scandone(pll_scandone),
    .read_param(0),
    .reconfig(pll_reconfig),
    .reset(pll_reconfig_reset),
    .reset_rom_address(0),
    .rom_address_out(pll_rom_address),
    .rom_data_in(pll_rom_q),
    .write_from_rom(pll_write_from_rom),
    .write_param(0),
    .write_rom_ena(pll_write_rom_ena)
);

always @(posedge clk32) begin
    reg ntsc_d, ntsc_d2, ntsc_d3;
    reg [1:0] pll_reconfig_state = 0;
    reg [9:0] pll_reconfig_timeout;

    ntsc_d <= ntsc;
    ntsc_d2 <= ntsc_d;
    pll_write_from_rom <= 0;
    pll_reconfig <= 0;
    pll_reconfig_reset <= 0;
    case (pll_reconfig_state)
    2'b00:
    begin
        ntsc_d3 <= ntsc_d2;
        if (ntsc_d2 ^ ntsc_d3) begin
            pll_write_from_rom <= 1;
            pll_reconfig_state <= 2'b01;
        end
    end
    2'b01: pll_reconfig_state <= 2'b10;
    2'b10:
        if (~pll_reconfig_busy) begin
            pll_reconfig <= 1;
            pll_reconfig_state <= 2'b11;
            pll_reconfig_timeout <= 10'd1000;
        end
    2'b11:
    begin
        pll_reconfig_timeout <= pll_reconfig_timeout - 1'd1;
        if (pll_reconfig_timeout == 10'd1) begin
            // pll_reconfig stuck in busy state
            pll_reconfig_reset <= 1;
            pll_reconfig_state <= 2'b00;
        end
        if (~pll_reconfig & ~pll_reconfig_busy) pll_reconfig_state <= 2'b00;
    end
    default: ;
    endcase
end
// ---------------------------------------------------------------------------------
// ----------------------------------- floppy 1541 ---------------------------------
// ---------------------------------------------------------------------------------

wire led_disk;
assign LED = !led_disk && cass_motor;

wire c16_iec_atn_o;
wire c16_iec_data_o;
wire c16_iec_clk_o;

wire c16_iec_atn_i  = c1541_iec_atn_o;
wire c16_iec_data_i = c1541_iec_data_o;
wire c16_iec_clk_i  = c1541_iec_clk_o;

wire c1541_iec_atn_o;
wire c1541_iec_data_o;
wire c1541_iec_clk_o;

wire c1541_iec_atn_i  = c16_iec_atn_o;
wire c1541_iec_data_i = c16_iec_data_o;
wire c1541_iec_clk_i  = c16_iec_clk_o;

c1541_sd c1541_sd (
	.clk32 ( clk32 ),
	.reset ( reset ),

	.disk_change ( img_mounted ),
	.disk_mount  ( |img_size ),
	.disk_num ( 10'd0 ), // always 0 on MiST, the image is selected by the OSD menu

	.iec_atn_i  ( c1541_iec_atn_i  ),
	.iec_data_i ( c1541_iec_data_i ),
	.iec_clk_i  ( c1541_iec_clk_i  ),

	.iec_atn_o  ( c1541_iec_atn_o  ),
	.iec_data_o ( c1541_iec_data_o ),
	.iec_clk_o  ( c1541_iec_clk_o  ),

   .sd_lba         ( sd_lba         ),
   .sd_rd          ( sd_rd          ),
   .sd_wr          ( sd_wr          ),
   .sd_ack         ( sd_ack         ),
   .sd_buff_din    ( sd_din         ),
   .sd_buff_dout   ( sd_dout        ),
   .sd_buff_wr     ( sd_dout_strobe ),
   .sd_buff_addr   ( sd_buff_addr   ),
   .led ( led_disk ),

   .c1541rom_clk   ( clk28         ),
   .c1541rom_addr  ( rom_dl_addr    ),
   .c1541rom_data  ( rom_dl_data    ),
   .c1541rom_wr    ( c1541_dl_wr    )
);

endmodule
