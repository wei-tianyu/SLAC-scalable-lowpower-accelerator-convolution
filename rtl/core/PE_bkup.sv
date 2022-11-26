`timescale 1ns/100ps
/*
 * @Author: Tianyu Wei 
 * @Date: 2022-11-04 11:41:51 
 * @Last Modified by:   Tianyu Wei 
 * @Last Modified time: 2022-11-04 11:41:51 
 */
module PE (  
	clk, reset,

	// configuration
	i_filter_width, i_pe_en, i_stride,
	// write input
	i_ifmap_data, i_ifmap_valid, i_reset_ifmap,
	i_en_loadi_left, i_en_loadi_upper,
	// write weight
	i_weight_data, 	i_weight_valid,
	i_wr_w_row_ptr, i_wr_w_col_ptr,
	// output
	o_peout_data, o_peout_valid,
	// allow right/lower PE load ifmap
	o_en_loadi_right, o_en_loadi_lower
);

    // synopsys template
	parameter 	DATA_WIDTH = 16;
	parameter 	MAX_FILTER_WIDTH = 11;	//AlexNet max configuration
	localparam	LOG_MFW = $clog2(MAX_FILTER_WIDTH);

	input  logic clk, reset;
	input  logic [LOG_MFW:0] i_filter_width;
	input  logic i_pe_en;
	input  logic [LOG_MFW:0] i_stride;
	input  logic [DATA_WIDTH-1:0] i_ifmap_data;
	input  logic i_ifmap_valid;
	input  logic i_reset_ifmap;
	input  logic i_en_loadi_left, i_en_loadi_upper;
	input  logic [DATA_WIDTH-1:0] i_weight_data;
	input  logic i_weight_valid;
	input  logic [LOG_MFW:0] i_wr_w_row_ptr;
	input  logic [LOG_MFW:0] i_wr_w_col_ptr;
	output logic [DATA_WIDTH-1:0] o_peout_data;
	output logic o_peout_valid;  // This is a pulse
	output logic o_en_loadi_right, o_en_loadi_lower;

	logic [MAX_FILTER_WIDTH-1:0][MAX_FILTER_WIDTH-1:0][DATA_WIDTH-1:0] weight;
	logic [LOG_MFW:0] rd_w_row_ptr;
	logic [LOG_MFW:0] rd_w_col_ptr;
	logic can_fill;
	logic row_loadi_en;
	logic pe_done;
	logic last_psum;
	logic reset_PEs;

	assign o_en_loadi_right = (rd_w_col_ptr == i_stride - 1);
	assign o_en_loadi_lower = (rd_w_row_ptr >= i_stride) || pe_done;
	assign can_fill = i_pe_en & i_ifmap_valid & row_loadi_en & i_en_loadi_upper;
	assign last_psum = (rd_w_row_ptr == i_filter_width - 1) && (rd_w_col_ptr == i_filter_width - 1);
	assign reset_PEs = reset | i_reset_ifmap;

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			weight <= 0;
		end
		else if(i_weight_valid && i_pe_en) begin
			weight[i_wr_w_row_ptr][i_wr_w_col_ptr]	<= i_weight_data;
		end
	end
	
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset_PEs) begin
			rd_w_row_ptr  <= 0;
			rd_w_col_ptr  <= 0;
			o_peout_data  <= 0;
			pe_done <= 0;
		end
		else if(can_fill && !pe_done) begin
			rd_w_row_ptr  <= (rd_w_col_ptr == i_filter_width - 1) ? 
						 	 ((rd_w_row_ptr == i_filter_width - 1) ? 0 : rd_w_row_ptr + 1) :
						 	 rd_w_row_ptr;
			rd_w_col_ptr  <= (rd_w_col_ptr == i_filter_width - 1) ? 0 : rd_w_col_ptr + 1;
			o_peout_data  <= o_peout_data + weight[rd_w_row_ptr][rd_w_col_ptr] * i_ifmap_data;
			pe_done       <= last_psum;
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset_PEs || o_peout_valid) begin
			o_peout_valid <= 0;
		end
		else if(can_fill && !pe_done) begin
			o_peout_valid <= last_psum;
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset_PEs) begin
			row_loadi_en <= 0;
		end
		else if(i_en_loadi_left) begin
			row_loadi_en <= 1;
		end
		else if(rd_w_col_ptr == i_filter_width - 1 && can_fill) begin
			row_loadi_en <= 0;
		end
	end

endmodule