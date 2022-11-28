`timescale 1ns/100ps
module PE_cluster #(
	parameter 	DATA_WIDTH = 16,
	parameter 	MAX_FILTER_WIDTH = 11,	//Also num of PEs in a row.
	localparam	LOG_MFW = $clog2(MAX_FILTER_WIDTH),
    parameter 	MAX_ROW_NUM = 16,
    localparam	LOG_MRN = $clog2(MAX_ROW_NUM)
) (
	input  logic clk, reset,
	// configuration
	input  logic [LOG_MFW:0] i_filter_width,
	input  logic [LOG_MRN:0] i_row_num,
	input  logic [LOG_MFW:0] i_stride,
	// write input
	input  logic [DATA_WIDTH-1:0] i_ifmap_data,
	input  logic i_ifmap_valid,
	input  logic i_reset_ifmap,
	// write weight
	input  logic [DATA_WIDTH-1:0] i_weight_data,
	input  logic i_weight_valid,
	input  logic [LOG_MFW:0] i_wr_w_row_ptr,
	input  logic [LOG_MFW:0] i_wr_w_col_ptr,
	input  logic [LOG_MRN:0] i_row_num,
	// output
	output wor   [DATA_WIDTH-1:0] o_peout_data,
	output logic o_peout_valid  // This is a pulse
);

	logic [MAX_ROW_NUM-1:0][MAX_FILTER_WIDTH-1:0] en_loadi_upper;
	logic [MAX_ROW_NUM-1:0][MAX_FILTER_WIDTH-1:0] en_loadi_lower;
	logic [MAX_ROW_NUM-1:0][DATA_WIDTH-1:0] peout_data; 
    logic [MAX_ROW_NUM-1:0] peout_valid;
    logic [MAX_ROW_NUM-1:0] last_psum;
    logic [MAX_ROW_NUM-1:0] row_en;
	logic switch_lane;
 	genvar i;
    generate
        for(i = 0; i < MAX_ROW_NUM; i++) begin

			assign row_en[i] = (i < i_row_num);

            PE_row #(
				.DATA_WIDTH(DATA_WIDTH),
				.MAX_FILTER_WIDTH(MAX_FILTER_WIDTH)
			) proc_ele_row (
				.clk(clk), .reset(reset),
				// configuration
				.i_filter_width(i_filter_width),
				.i_row_en(row_en[i]),
				.i_stride(i_stride),
				// write input
				.i_ifmap_data(i_ifmap_data),
				.i_ifmap_valid(i_ifmap_valid),
				.i_reset_ifmap(i_reset_ifmap),
				.i_en_loadi_upper(en_loadi_upper[i]),
				.i_switch_lane(switch_lane),
				// write weight
				.i_weight_data(i_weight_data),
				.i_weight_valid(i_weight_valid),
				.i_wr_w_row_ptr(i_wr_w_row_ptr),
				.i_wr_w_col_ptr(i_wr_w_col_ptr),
				// output
				.o_peout_data(peout_data[i]),
				.o_peout_valid(peout_valid[i]),  // This is a pulse
				// allow lower PE load ifmap
				.o_en_loadi_lower(en_loadi_lower[i])
				.o_last_psum(last_psum[i])
			);
        end

		for(i = 0; i < MAX_ROW_NUM; i++) begin
			if(i == 0) assign en_loadi_upper[0] = '1;
			else       assign en_loadi_upper[i] = en_loadi_lower[i-1];
		end

		for(i = 0; i < MAX_ROW_NUM; i++) begin
            assign o_peout_data = peout_data[i] & {DATA_WIDTH{peout_valid[i]}};
        end
    endgenerate

	assign o_peout_valid = | peout_valid;
	assign switch_lane   = last_psum[i_row_num - 1];
	
	// synopsys sync_set_reset "reset"
	always_ff @( posedge clk ) begin:
		if(reset) begin
			first_batch <= 1;
		end
		else if(i_reset_ifmap) begin:
			first_batch <= 1;
		end
		else if(i_weight_valid && i_pe_en) begin
			weight[i_wr_w_row_ptr][i_wr_w_col_ptr]	<= i_weight_data;
		end
	end

endmodule