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
	logic [MAX_FILTER_WIDTH-1:0][DATA_WIDTH-1:0] w_row;
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
	logic [MAX_FILTER_WIDTH-1:0] wr_w_col_ptr;
	logic [MAX_FILTER_WIDTH-1:0] wr_w_row_ptr;
	logic [LOG_MFW-1:0] rd_w_row_ptr;
	logic [MAX_FILTER_WIDTH-1:0][LOG_MFW-1:0] rd_w_col_ptr;
	logic [MAX_FILTER_WIDTH-1:0] rd_w_en;
	logic [MAX_FILTER_WIDTH-1:0] wr_w_en;
	logic [1:0][DATA_WIDTH-1:0] psum;
	logic [LOG_MFW-1:0] current_col;

	////////////////////////////////////////////////////////////////////////////////////////////
	// module instantiation
	////////////////////////////////////////////////////////////////////////////////////////////
	
	// shift register for weight
	genvar i;
	generate
		// MAX_FILTER_WIDTH rows
		for(i = 0; i < MAX_FILTER_WIDTH; i++) begin
			shift_reg #( 
				.DATA_WIDTH(DATA_WIDTH),
				.DEPTH(MAX_FILTER_WIDTH)
			) lane_w (
				.clk(clk),
				.reset(reset),
				.i_ren(rd_w_en[i]),
				.i_wen(wr_w_en[i]),
				.i_used_depth(i_filter_width),
				.i_wdata(i_weight_data),
				.o_rdata(w_row[i]),
				.o_rd_ptr(rd_w_col_ptr[i])
			);
		end
	endgenerate

	////////////////////////////////////////////////////////////////////////////////////////////
	// behavior
	////////////////////////////////////////////////////////////////////////////////////////////

	// 0. weight wr
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			wr_w_col_ptr <= 1;
		end
		else if(i_weight_valid && i_pe_en) begin
			wr_w_col_ptr  <= (wr_w_col_ptr[i_filter_width-1]) ? 1 : wr_w_col_ptr << 1;
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			wr_w_row_ptr <= 1;
		end
		else if(i_weight_valid && i_pe_en && wr_w_col_ptr[i_filter_width-1]) begin
			wr_w_row_ptr  <= (wr_w_row_ptr[i_filter_width-1]) ? 1 : wr_w_row_ptr << 1;
		end
	end

	assign wr_w_en = wr_w_row_ptr & {MAX_FILTER_WIDTH{i_weight_valid}} & {MAX_FILTER_WIDTH{i_pe_en}};

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
	assign o_last_psum         = (rd_w_row_ptr == i_filter_width - 1) && o_last_in_row;
	assign o_last_in_row       = (current_col == i_filter_width - 1) && accept_ifmap;
	assign o_en_loadi_right    = (current_col >= i_stride);
	assign o_en_loadi_lower    = (rd_w_row_ptr >= i_stride) || pe_done;
	assign accept_ifmap        = i_pe_en & i_ifmap_valid & row_loadi_en & i_en_loadi_upper;
	assign newline		   	   = i_newline & i_en_loadi_upper;
	assign current_col		   = rd_w_col_ptr[rd_w_row_ptr];

	always_comb begin
		if(i_row_done && (lane_feed == lane_cal)) row_loadi_en = 1;
		else row_loadi_en = i_en_loadi_left;
	end

	// 3. new ifmap come in, updates ptr
	generate
		for(i = 0; i < MAX_FILTER_WIDTH; i++) begin
			assign rd_w_en[i] = accept_ifmap && (rd_w_row_ptr == i);
		end
	endgenerate
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

	// 4. new ifmap come in, updates psum x 2.
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
			psum[lane_feed] <= psum[lane_feed] + w_row[rd_w_row_ptr] * i_ifmap_data;
		end
	end
endmodule