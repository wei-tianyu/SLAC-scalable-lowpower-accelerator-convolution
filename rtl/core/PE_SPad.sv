`timescale 1ns/100ps
/*
 * @Author: Tianyu Wei 
 * @Date: 2022-11-04 11:41:51 
 * @Last Modified by:   Tianyu Wei 
 * @Last Modified time: 2022-11-04 11:41:51 
 */
module PE #(
	// synopsys template
	parameter 	DATA_WIDTH = 16,
	parameter 	MAX_FILTER_WIDTH = 11,	//AlexNet max configuration
	localparam	LOG_MFW = $clog2(MAX_FILTER_WIDTH)
	) (  
	input  logic clk, reset,
	// configuration
	input  logic [LOG_MFW:0] i_filter_width,
	input  logic i_pe_en,
	input  logic [LOG_MFW:0] i_stride,
	// write input
	input  logic [DATA_WIDTH-1:0] i_ifmap_data,
	input  logic i_ifmap_valid,
	input  logic i_reset_ifmap,
	input  logic i_en_loadi_left, i_en_loadi_upper,
	input  logic i_newline,			// next data will be from next line in input
	input  logic i_switch_lane,     // next data's calculation will be from the new lane
	// write weight
	input  logic [DATA_WIDTH-1:0] i_weight_data,
	input  logic i_weight_valid,
	input  logic [LOG_MFW:0] i_wr_w_row_ptr,
	input  logic [LOG_MFW:0] i_wr_w_col_ptr,
	// output
	output logic [DATA_WIDTH-1:0] o_peout_data,
	output logic o_peout_valid,  // This is a pulse
	// allow right/lower PE load ifmap
	output logic o_en_loadi_right, o_en_loadi_lower,
	// row done signal pass to right
	input  logic i_row_done,
	output logic o_row_done,
	output logic o_last_in_row,
	output logic o_last_psum
);

	////////////////////////////////////////////////////////////////////////////////////////////
	// variables
	////////////////////////////////////////////////////////////////////////////////////////////
	
	// weight memory
	logic [MAX_FILTER_WIDTH-1:0][MAX_FILTER_WIDTH-1:0][DATA_WIDTH-1:0] weight;
	// lane select
	logic lane_feed;
	logic lane_cal;
	logic next_lane_cal;
	logic pe_done;
	// PE state
	logic row_loadi_en;
	logic accept_ifmap;
	logic newline;
	// lane ptrs
	logic [1:0][LOG_MFW:0] w_col_ptr;
	logic [LOG_MFW:0] rd_w_col_ptr;
	logic [LOG_MFW:0] rd_w_row_ptr;
	logic [1:0][LOG_MFW:0] restart_col;
	
	///////////////////////////////
	logic [1:0][DATA_WIDTH-1:0] psum;///////////////////////
	

	////////////////////////////////////////////////////////////////////////////////////////////
	// behavior
	////////////////////////////////////////////////////////////////////////////////////////////

	// 0. weight wr
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			weight <= 0;
		end
		else if(i_weight_valid && i_pe_en) begin
			weight[i_wr_w_row_ptr][i_wr_w_col_ptr]	<= i_weight_data;
		end
	end

	// 1. which lane is under calculation, which lane is fed
	assign next_lane_cal	= ~lane_cal;
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			lane_cal <= 0;
		end
		else if(i_reset_ifmap || !i_pe_en) begin
			lane_cal <= 0;
		end
		else if(i_pe_en && i_switch_lane) begin
			lane_cal <= next_lane_cal;
		end
	end
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			lane_feed <= 0;
		end
		else if(i_reset_ifmap || !i_pe_en) begin
			lane_feed <= 0;
		end
		else if(i_switch_lane) begin
			lane_feed <= next_lane_cal;
		end
		else if(newline) begin
			lane_feed <= lane_cal;
		end
		else if(o_last_in_row) begin
			lane_feed <= next_lane_cal;
		end
	end

	// 2. communication with adjacent PE - feed enable signal
	assign o_last_psum           = (rd_w_row_ptr == i_filter_width - 1) && o_last_in_row;
	assign o_last_in_row         = (w_col_ptr[lane_cal] == i_filter_width - 1) && accept_ifmap;
	assign o_en_loadi_right    = (w_col_ptr[lane_feed] >= i_stride);
	assign o_en_loadi_lower    = (rd_w_row_ptr >= i_stride) || pe_done;
	assign accept_ifmap        = i_pe_en & i_ifmap_valid & row_loadi_en & i_en_loadi_upper;
	assign newline		   	   = i_newline & i_en_loadi_upper;

	always_comb begin
		if(i_row_done && (lane_feed == lane_cal)) row_loadi_en = 1;
		else row_loadi_en = i_en_loadi_left;
	end

	// 3. new ifmap come in, updates ptr
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			rd_w_row_ptr  <= 0;
		end
		else if(i_reset_ifmap) begin
			rd_w_row_ptr  <= 0;
		end
		else if(newline) begin
			rd_w_row_ptr  <= (rd_w_row_ptr == i_filter_width - 1) ? 0 : rd_w_row_ptr + 1;
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			w_col_ptr   <= 0;
			restart_col <= 0;
		end
		else if(i_reset_ifmap || !i_pe_en) begin
			w_col_ptr   <= 0;
			restart_col <= 0;
		end
		else if(i_switch_lane) begin
			w_col_ptr[next_lane_cal] <= restart_col[next_lane_cal];
			w_col_ptr[lane_cal]      <= 0;
			restart_col[lane_cal]    <= 0;
		end
		else if(newline) begin
			w_col_ptr[lane_cal]    <= restart_col[lane_cal];
			w_col_ptr[lane_feed]   <= 0;
			restart_col[lane_feed] <= w_col_ptr[lane_feed] + 1;
		end
		else if(accept_ifmap) begin
			w_col_ptr[lane_feed] <= (w_col_ptr[lane_feed] == i_filter_width - 1) ? 
									(o_row_done ? 0 : restart_col[lane_cal])     :
									w_col_ptr[lane_feed] + 1;
		end
	end

	// 4. new ifmap come in, updates psum x 2.
	assign rd_w_col_ptr  = w_col_ptr[lane_feed];
	assign o_peout_data  = psum[~lane_feed];
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			o_row_done <= 0;
			pe_done    <= 0;
		end
		else if(i_reset_ifmap || newline || i_switch_lane) begin
			o_row_done <= 0;
			pe_done    <= 0;
		end
		else if(accept_ifmap) begin
			o_row_done    <= o_last_in_row;
			pe_done       <= o_last_psum;
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset)                               o_peout_valid <= 0;
		else if(i_reset_ifmap || o_peout_valid) o_peout_valid <= 0;
		else                                    o_peout_valid <= o_last_psum;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			psum <= 0;
		end
		else if(i_reset_ifmap) begin
			psum <= 0;
		end
		else if(accept_ifmap) begin
			if (o_peout_valid) begin
				psum[~lane_feed] <= 0;
			end
			psum[lane_feed] <= psum[lane_feed] + weight[rd_w_row_ptr][rd_w_col_ptr] * i_ifmap_data;
		end
	end
endmodule