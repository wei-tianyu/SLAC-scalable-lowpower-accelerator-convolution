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
    logic [DEPTH-1:0] used;
    logic [DATA_WIDTH-1:0][DEPTH-1:0] shift_mem;
    logic [DATA_WIDTH-1:0][DEPTH-1:0] next_mem;

    genvar i, j;
    generate
        for(i = 0; i < DATA_WIDTH; i++) begin
            assign o_rdata[i] = mem[i][0];
            
            assign shift_mem[i]  = {mem[i][0], mem[i][DEPTH-1:1]};

            for(j = 0; j < DEPTH; j++) begin
                always_comb begin
                    if(i_ren)
                        next_mem[i][j] = used[j] ? shift_mem[i][j] : mem[i][0];
                    else if(i_wen)
                        next_mem[i][j] = (j==i_used_depth-1) ? i_wdata[i] :
                                         (used[j] ? shift_mem[i] : 0);
                    else
                        next_mem[i][j] = mem[i][j];
                end
            end

            // synopsys sync_set_reset "reset"
            always_ff @(posedge clk) begin
                if(reset) begin
                    mem[i] <= 0;
                end
                else begin
                    mem[i] <= next_mem[i];
                end
            end
        end
    endgenerate

    generate
        for(i = 0; i < DEPTH; i++) begin
            assign used[i] = (i < i_used_depth);
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