`timescale 1ns/100ps
module shift_reg #( 
	// synopsys template
	parameter DATA_WIDTH = 16,
    parameter DEPTH      = 11,
    localparam LOG_DEPTH = $clog2(DEPTH)
) (
	input  logic clk,
	input  logic reset,
	input  logic i_ren,
	input  logic i_wen,
    input  logic [LOG_DEPTH : 0] i_used_depth,
	input  logic [DATA_WIDTH-1 : 0] i_wdata,
    output logic [DATA_WIDTH-1 : 0] o_rdata,
    output logic [LOG_DEPTH-1 : 0] o_rd_ptr
);
    // group in this order to facilitate shifting.
    logic [DATA_WIDTH-1:0][DEPTH-1:0] mem;

    genvar i;
    generate
        for(i = 0; i < DATA_WIDTH; i++) begin
            assign o_rdata[i] = mem[i][i_used_depth - 1];

            // synopsys sync_set_reset "reset"
            always_ff @(posedge clk) begin
                if(reset) begin
                    mem[i] <= 0;
                end
                else if(i_ren) begin
                    mem[i] <= {mem[i][DEPTH-2:0], mem[i][i_used_depth - 1]};
                end
                else if(i_wen) begin
                    mem[i] <= {mem[i][DEPTH-2:0], o_rdata[i]};
                end
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if(reset) begin
            o_rd_ptr <= 0;
        end
        else if(i_ren) begin
            o_rd_ptr <= (o_rd_ptr == i_used_depth - 1) ? 0 : o_rd_ptr + 1;
        end
    end
endmodule