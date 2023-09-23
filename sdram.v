//
// sdram.v
//
// sdram controller implementation for the MiST board
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

module sdram (

	// interface to the MT48LC16M16 chip
	inout  reg [15:0]	sd_data,    // 16 bit bidirectional data bus
	output reg [12:0]	sd_addr,    // 13 bit multiplexed address bus
	output reg [1:0] 	sd_dqm,     // two byte masks
	output reg[1:0] 	sd_ba,      // two banks
	output 				sd_cs,      // a single chip select
	output 				sd_we,      // write enable
	output 				sd_ras,     // row address select
	output 				sd_cas,     // columns address select

	// cpu/chipset interface
	input 		 		init,		// init signal after FPGA config to initialize RAM
	input 		 		clk,		// sdram is accessed at up to 128MHz
	input				clkref,		// reference clock to sync to
	
	input [15:0]  		din,		// data input from chipset/cpu
	output reg [15:0]	dout,		// data output to chipset/cpu
	input [23:0]   		addr,       // 24 bit word address
	input [1:0] 		ds,         // data strobe for hi/low byte
	input 		 		oe,         // cpu/chipset requests read
	input 		 		we          // cpu/chipset requests write
);

// no burst configured
localparam RASCAS_DELAY   = 3'd1;   // tRCD>=20ns -> 1 cycle@32MHz
localparam BURST_LENGTH   = 3'b000; // 000=none, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

localparam STATE_IDLE      = 4'd0;    // first state in cycle
localparam STATE_CMD_START = 4'd1;    // state in which a new command can be started
localparam STATE_CMD_CONT  = STATE_CMD_START  + RASCAS_DELAY; // 2 command can be continued
localparam STATE_DATA_READY= STATE_CMD_CONT + CAS_LATENCY + 1'd1;
localparam STATE_LAST      = 4'd7;   // last state in cycle

reg [2:0] q /* synthesis noprune */;
always @(posedge clk) begin
	reg last_clkref;
	last_clkref <= clkref;

	// Sync SDRAM cycle to rising edge of clkref
	q <= q + 1'd1;
	if (~last_clkref & clkref) q <= 0;

end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// wait 1ms (32 clkref cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [4:0] reset = 5'h1f;
always @(posedge clk, posedge init) begin
	if(init)	reset <= 5'h1f;
	else if((q == STATE_LAST) && (reset != 0))
		reset <= reset - 5'd1;
end

// ---------------------------------------------------------------------
// ------------------ generate ram control signals ---------------------
// ---------------------------------------------------------------------

// all possible commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

reg [3:0] sd_cmd;   // current command sent to sd ram

// drive control signals according to current command
assign sd_cs  = sd_cmd[3];
assign sd_ras = sd_cmd[2];
assign sd_cas = sd_cmd[1];
assign sd_we  = sd_cmd[0];

always @(posedge clk) begin
	sd_cmd <= CMD_INHIBIT;
	sd_data <= 16'bZZZZZZZZZZZZZZZZ;

	if(reset != 0) begin
		sd_ba <= 2'b00;
		sd_dqm <= 2'b00;
			
		if(reset == 13) sd_addr <= 13'b0010000000000;
		else   			 sd_addr <= MODE;

		if(q == STATE_IDLE) begin
			if(reset == 13)  sd_cmd <= CMD_PRECHARGE;
			if(reset ==  2)  sd_cmd <= CMD_LOAD_MODE;
		end
	end else begin
		if(q <= STATE_CMD_START) begin	
			sd_addr <= { addr[20:15], addr[6:0] };
			sd_ba <= addr[22:21];
			sd_dqm <= { !ds[1], !ds[0] };
		end else
			sd_addr <= { 4'b0010, addr[23], addr[14:7]};
	
		if(q == STATE_IDLE) begin
			if(we || oe) sd_cmd <= CMD_ACTIVE;
			else         sd_cmd <= CMD_AUTO_REFRESH;
		end else if(q == STATE_CMD_CONT) begin
			if(we)		 sd_cmd <= CMD_WRITE;
			else if(oe)  sd_cmd <= CMD_READ;
			if(we)		 sd_data <= din;
		end else if(q == STATE_DATA_READY) begin
			if(oe)		 dout <= sd_data;
		end
	end
end

endmodule
