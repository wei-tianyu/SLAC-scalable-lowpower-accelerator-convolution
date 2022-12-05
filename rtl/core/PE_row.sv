`timescale 1ns/100ps
module PE_row #(
    
	parameter 	DATA_WIDTH = 16,
	parameter 	MAX_FILTER_WIDTH = 11,	//Also num of PEs in a row.
	localparam	LOG_MFW = $clog2(MAX_FILTER_WIDTH)
) (
    input  logic clk, reset,
    // configuration
    input  logic [LOG_MFW:0] i_filter_width,
	input  logic i_row_en,
	input  logic [LOG_MFW:0] i_stride,
    // write input
	input  logic [DATA_WIDTH-1:0] i_ifmap_data,
	input  logic i_ifmap_valid,
	input  logic i_reset_ifmap,
    input  logic [MAX_FILTER_WIDTH-1:0] i_en_loadi_upper,
    input  logic i_switch_lane,
    // write weight
	input  logic [DATA_WIDTH-1:0] i_weight_data,
	input  logic i_weight_valid,
    // output
	output wor   [DATA_WIDTH-1:0] o_peout_data,
	output logic o_peout_valid,  // This is a pulse
    // allow lower PE load ifmap
	output logic [MAX_FILTER_WIDTH-1:0] o_en_loadi_lower,
    output logic o_last_psum
);
    logic [MAX_FILTER_WIDTH-1:0] pe_en;
    logic [MAX_FILTER_WIDTH-1:0] en_loadi_left;
    logic [MAX_FILTER_WIDTH-1:0] en_loadi_right; 
    logic [MAX_FILTER_WIDTH-1:0] row_done_i;
    logic [MAX_FILTER_WIDTH-1:0] row_done_o;
    logic [MAX_FILTER_WIDTH-1:0][DATA_WIDTH-1:0] peout_data; 
    logic [MAX_FILTER_WIDTH-1:0] peout_valid;
    logic newline;
    logic [MAX_FILTER_WIDTH-1:0] last_in_row;
    logic [MAX_FILTER_WIDTH-1:0] last_psum;

    genvar i;
    generate
        for(i = 0; i < MAX_FILTER_WIDTH; i++) begin

            assign pe_en[i] = (i < i_filter_width) & i_row_en;

            PE #(
	            .DATA_WIDTH(DATA_WIDTH),
	            .MAX_FILTER_WIDTH(MAX_FILTER_WIDTH)
	            ) proc_ele (  
	            .clk(clk), .reset(reset),
	            // configuration
	            .i_filter_width(i_filter_width),
	            .i_pe_en(pe_en[i]),
	            .i_stride(i_stride),
	            // write input
	            .i_ifmap_data(i_ifmap_data),
	            .i_ifmap_valid(i_ifmap_valid),
	            .i_reset_ifmap(i_reset_ifmap),
	            .i_en_loadi_left(en_loadi_left[i]), 
                .i_en_loadi_upper(i_en_loadi_upper[i]),
	            .i_newline(newline),			// next data will be from next line in input
	            .i_switch_lane(i_switch_lane),     // next data's calculation will be from the new lane
	            // write weight
	            .i_weight_data(i_weight_data),
	            .i_weight_valid(i_weight_valid),
	            // output
	            .o_peout_data(peout_data[i]),
	            .o_peout_valid(peout_valid[i]),  // This is a pulse
	            // allow right/lower PE load ifmap
	            .o_en_loadi_right(en_loadi_right[i]), 
                .o_en_loadi_lower(o_en_loadi_lower[i]),
	            // row done signal pass to right
	            .i_row_done(row_done_i[i]),
	            .o_row_done(row_done_o[i]),
                .o_last_in_row(last_in_row[i]),
                .o_last_psum(last_psum[i])
            );
        end
    endgenerate

    generate
        for(i = 0; i < MAX_FILTER_WIDTH; i++) begin
            if(i != 0) begin
                assign en_loadi_left[i] = en_loadi_right[i-1];
            end
            else begin
                assign en_loadi_left[0] = en_loadi_right[MAX_FILTER_WIDTH - 1];
            end
        end
        for(i = 0; i < MAX_FILTER_WIDTH; i++) begin
            assign o_peout_data = peout_data[i] & {DATA_WIDTH{peout_valid[i]}};
        end
        for(i = 0; i < MAX_FILTER_WIDTH; i++) begin
            if(i != 0) begin
                assign row_done_i[i] = row_done_o[i-1];
            end
            else begin
                assign row_done_i[0] = 1'b1;
            end
        end
    endgenerate

    assign o_peout_valid = | peout_valid;
    assign newline       = last_in_row[i_filter_width - 1];
    assign o_last_psum   = last_psum[i_filter_width - 1];

endmodule