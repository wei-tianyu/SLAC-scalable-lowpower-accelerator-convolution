`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/27/2019 10:35:28 AM
// Design Name: 
// Module Name: SPad
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SPad #( 
	// synopsys template
	parameter DATA_WIDTH = 16,
	parameter ADDR_BITWIDTH = 9
) (
	input  logic clk,
	input  logic reset,
	input  logic i_ren,
	input  logic i_wen,
	input  logic [ADDR_BITWIDTH-1 : 0] i_raddr,
	input  logic [ADDR_BITWIDTH-1 : 0] i_waddr,
	input  logic [DATA_WIDTH-1 : 0] i_wdata,
	output logic [DATA_WIDTH-1 : 0] o_rdata
);
	
	logic [0 : (1 << ADDR_BITWIDTH) - 1][DATA_WIDTH-1 : 0] r_mem; 
	logic [DATA_WIDTH-1 : 0] r_data;
	
	always@(posedge clk)
	begin : READ
		if(reset)
			r_data <= 0;
		else
		begin
			if(i_ren) begin
				r_data <= r_mem[i_raddr];
			end else begin
				r_data <= 0;
			end
		end
	end
	
	assign o_rdata = r_data;
	
	always@(posedge clk)
	begin : WRITE
		if(i_wen && !reset) begin
			r_mem[i_waddr] <= i_wdata;
		end
	end
	
endmodule
