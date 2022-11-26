`timescale 1ns / 1ps
/*
 * @Author: Tianyu Wei 
 * @Date: 2022-10-28 15:56:23 
 * @Last Modified by:   Tianyu Wei 
 * @Last Modified time: 2022-10-28 15:56:23 
 */

module MAC( input [IN_BITWIDTH-1 : 0] i_in,
	  input [IN_BITWIDTH-1 : 0] w_in,
	  input [IN_BITWIDTH-1 : 0] sum_in,
	  input en, clk,
	  output logic [OUT_BITWIDTH-1 : 0] out
	);

	// synopsys template
	parameter IN_BITWIDTH = 16;
	parameter OUT_BITWIDTH = 2*IN_BITWIDTH;
	
	logic [OUT_BITWIDTH-1:0] mult_out;
	assign mult_out = i_in * w_in;
	
	always@(posedge clk) begin
		if(en) begin
			out <= mult_out + sum_in;
		end
	end
	
endmodule
