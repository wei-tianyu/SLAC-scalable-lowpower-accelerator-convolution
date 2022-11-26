`timescale 1ns/100ps
/*
 * @Author: Tianyu Wei 
 * @Date: 2022-11-04 11:41:51 
 * @Last Modified by:   Tianyu Wei 
 * @Last Modified time: 2022-11-04 11:41:51 
 */
module PE_cluster (
    clk, reset,
    // Configuration
    i_filter_width, i_ofmap_data, i_stride,
    // write ifmap
    i_ifmap_data, i_ifmap_valid, i_reset_ifmap,
    //write weight
    i_weight_data, i_weight_valid,
    i_wr_w_row_ptr, i_wr_w_col_ptr,
    // output
    o_peout_data, o_peout_valid, o_peout_row, o_peout_col
);

    parameter 	DATA_WIDTH = 16;
    parameter   NUM_PES = 16;        //No. of PEs in a PE_cluster
    parameter 	MAX_FILTER_WIDTH = 11;	//AlexNet max configuration
	localparam	LOG_MFW = $clog2(MAX_FILTER_WIDTH);
    localparam	LOG_NPE = $clog2(NUM_PES);

    input  logic clk, reset;
    input  logic [LOG_MFW:0] i_filter_width;
    input  logic [LOG_NPE:0] i_ofmap_data;
    input  logic [LOG_MFW:0] i_stride;
    input  logic [DATA_WIDTH-1:0] i_ifmap_data;
    input  logic i_ifmap_valid;
    input  logic i_reset_ifmap;
    input  logic [DATA_WIDTH-1:0] i_weight_data;
	input  logic i_weight_valid;
    input  logic [LOG_MFW:0] i_wr_w_row_ptr;
	input  logic [LOG_MFW:0] i_wr_w_col_ptr;
    output logic [DATA_WIDTH-1:0] o_peout_data;
	output wor   o_peout_valid;
	output logic [LOG_NPE:0]o_peout_row;
	output logic [LOG_NPE:0]o_peout_col;
    
    logic [NUM_PES-1:0][NUM_PES-1:0] pe_en;
    logic [NUM_PES-1:0][NUM_PES-1:0] en_loadi_right;
    logic [NUM_PES-1:0][NUM_PES-1:0] en_loadi_lower;
    logic [NUM_PES-1:0][NUM_PES-1:0] en_loadi_left;
    logic [NUM_PES-1:0][NUM_PES-1:0] en_loadi_upper;
    logic [NUM_PES-1:0][NUM_PES-1:0][DATA_WIDTH-1:0] peout_data;
    logic reset_PEs;

    assign reset_PEs = reset | i_reset_ifmap;

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset_PEs) begin
			o_peout_row  <= 0;
			o_peout_col  <= 0;
		end
		else if(o_peout_valid) begin
			o_peout_row <= (o_peout_col == i_ofmap_data - 1) ? 
						   ((o_peout_row == i_ofmap_data - 1) ? 0 : o_peout_row + 1) :
						   o_peout_row;
			o_peout_col <= (o_peout_col == i_filter_width - 1) ? 0 : o_peout_col + 1;
		end
	end

    assign o_peout_data = peout_data[o_peout_row][o_peout_col];


    genvar i, j;
    generate
        for(i = 0; i < NUM_PES; i++) begin
            for(j = 0; j < NUM_PES; j++) begin
                PE #(.DATA_WIDTH(DATA_WIDTH), .MAX_FILTER_WIDTH(MAX_FILTER_WIDTH)) proc_ele (
                    .*,
                    .i_pe_en(pe_en[i][j]),
                    .i_en_loadi_left(en_loadi_left[i][j]),
                    .i_en_loadi_upper(en_loadi_upper[i][j]),
                    .o_peout_data(peout_data[i][j]),
                    .o_en_loadi_right(en_loadi_right[i][j]),
                    .o_en_loadi_lower(en_loadi_lower[i][j])
                );
            end
        end
    endgenerate

    assign en_loadi_upper[0] = '1;
    generate
        for(i = 0; i < NUM_PES; i++) begin
            assign en_loadi_left[i][0] = 1;
            if (i != 0) assign en_loadi_upper[i] = en_loadi_lower[i-1];
        end
    endgenerate
    generate
        for(i = 0; i < NUM_PES; i++) begin
            for(j = 0; j < NUM_PES; j++) begin
                if (j != 0) assign en_loadi_left[i][j] = en_loadi_right[i][j-1];
            end
        end
    endgenerate

    generate
        for(i = 0; i < NUM_PES; i++) begin
            for(j = 0; j < NUM_PES; j++) begin
                assign pe_en[i][j] = (i < i_ofmap_data) && (j < i_ofmap_data);
            end
        end
    endgenerate



endmodule