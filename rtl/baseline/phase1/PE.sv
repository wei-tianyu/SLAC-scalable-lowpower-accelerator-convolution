`timescale 1ns / 1ps
/*
 * @Author: Tianyu Wei 
 * @Date: 2022-10-28 15:40:44 
 * @Last Modified by: Tianyu Wei
 * @Last Modified time: 2022-10-28 15:57:23
 */

module PE (  
	clk, reset,

	i_ifmap_in,	i_loadifmap_en,
	i_weight_in,	i_loadweight_en, 

	i_start,
	o_pe_out,
	o_conv_done,
	o_load_done
);

	// synopsys template
	parameter DATA_WIDTH = 16;
	parameter ADDR_WIDTH = 9;

	parameter W_READ_ADDR = 0;     //Weights beginning address in SPad
	parameter I_READ_ADDR = 100;   //ifmap beginning address in SPad

	parameter W_LOAD_ADDR = 0;     //Weights LOAD address
	parameter I_READ_ADDR = 100;   //ifmap LOAD address

	parameter PSUM_ADDR = 500;

	parameter KERNEL_WIDTH = 3;
	parameter IFMAP_WIDTH  = 5;

	input  logic clk, reset,
	input  logic [DATA_WIDTH-1:0] i_ifmap_in,
	input  logic [DATA_WIDTH-1:0] i_weight_in,
	input  logic i_loadweight_en, i_loadifmap_en,
	input  logic i_start,
	output logic [DATA_WIDTH-1:0] o_pe_out,
	output logic o_conv_done,IFMAP_WI
	
	enum logic [2:0] {IDLE=3'b000, READ_W=3'b001, READ_I=3'b010, COMPUTE=3'b011,
					  WRITE=3'b100, LOAD_W=3'b101, LOAD_A=3'b110} state;

	logic r_read_en, r_write_en;
	logic [ADDR_WIDTH-1:0] r_waddr, r_raddr;
	logic [DATA_WIDTH-1:0] r_rdata, r_wdata;
	
	SPad spad_pe0 ( .clk(clk), .reset(reset), 
					.i_ren(r_read_en),
					.i_wen(r_write_en), 
					.i_raddr(r_raddr), 
					.i_waddr(r_waddr),
					.i_wdata(r_wdata),
					.o_rdata(r_rdata)
					);
					

	logic [DATA_WIDTH-1:0] w_mac_out;
	logic [DATA_WIDTH-1:0] w_sum_in;
	logic sum_in_sel;
	
	logic [DATA_WIDTH-1:0] r_ifmap_in;
	logic [DATA_WIDTH-1:0] r_filt_in;
	
	logic mac_en;
	
	//multiplication-accumulation
	MAC  #( .IN_BITWIDTH(DATA_WIDTH),
			.OUT_BITWIDTH(DATA_WIDTH) )
	mac_0( 
		.i_in(r_ifmap_in),
		.w_in(r_filt_in),
		.w_sum_in(w_sum_in),
		.en(mac_en),
		.clk(clk),
		.out(w_mac_out)
	);
			
	assign w_sum_in = sum_in_sel ? w_mac_out : 0;
	
	
	logic [7:0] filt_count;
	logic [2:0] iter_row;
	
	// FSM for PE
	always@(posedge clk) 
	begin
//		$display("State: %s", state.name());
		if(reset) 
		begin
			//Initialize registers
			filt_count <= 0;
			sum_in_sel <= 0;
			
			//Initialize scratchpad inputs
			r_waddr <= W_READ_ADDR;
			r_raddr <= W_READ_ADDR;
			r_wdata <= 0;
			r_write_en <= 0;
			r_read_en <= 0;
			o_conv_done <= 0;
			mac_en <= 0;
			iter_row <= 0;
			o_load_done <= 0;
			state <= IDLE;
		end
		else 
		begin
			case(state)
				IDLE:begin
					if(i_start) begin
						if(iter_row == (IFMAP_WIDTH-KERNEL_WIDTH+1) ) begin
							iter_row <= 0;
							state <= IDLE;
						end else begin
							r_raddr <= I_READ_ADDR + iter_row * IFMAP_WIDTH;
							filt_count <= 0;
							sum_in_sel <= 0;
							r_read_en <= 1;
							state <= READ_W;
						end
					end else begin
						if(i_loadweight_en) begin
							r_waddr <= W_LOAD_ADDR;  //***Loading of weights starts at index 0***
							r_wdata <= i_weight_in;
							r_write_en <= 1;
							filt_count <= 0;
							state <= LOAD_W;
						end else if(i_loadifmap_en) begin
							r_write_en <= 1;
							r_waddr <= I_READ_ADDR; // *** Loading of activations starts at 100 ***
							r_wdata <= i_ifmap_in;
							state <= LOAD_A;
						end else begin
							o_load_done <= 0;
							r_write_en <= 0;
							o_conv_done <= 0;
							state <= IDLE;
						end
					end
				end
				
				READ_W:begin
					r_filt_in <= r_rdata;
					r_read_en <= 1;
					filt_count <= filt_count + 1;
					state <= READ_I;
				end
				
				READ_I:begin
					r_ifmap_in <= r_rdata;
					r_read_en <= 1;
					r_raddr <= W_READ_ADDR + filt_count;
					mac_en <= 1;
					state <= COMPUTE;
				end
					
				COMPUTE:begin
					mac_en <= 0;
					if(filt_count == KERNEL_WIDTH) begin
						r_ifmap_in <= r_rdata;
						r_read_en <= 0;
						r_waddr <= PSUM_ADDR + iter_row;
						r_write_en <= 1;
						state <= WRITE;
					end else begin
						if(filt_count == 0) begin
							sum_in_sel <= 0;
						end else begin
							sum_in_sel <= 1;	
						end
						r_raddr <= I_READ_ADDR + filt_count + iter_row*IFMAP_WIDTH;
						state <= READ_W;
					end
				end
				
				WRITE:begin
					r_wdata <= w_mac_out;
					r_raddr <= W_READ_ADDR;
					r_read_en <= 1;
					iter_row <= iter_row + 1;
					o_conv_done <= 1;
					state <= IDLE;
				end
				
				LOAD_W:begin
					if(filt_count == (KERNEL_WIDTH**2-1)) begin
						filt_count <= 0;
						o_load_done <= 1;
						state <= IDLE;
					end else begin
						r_wdata <= i_weight_in;
						r_waddr <= r_waddr + 1;
						filt_count <= filt_count + 1;
						state <= LOAD_W;
					end
				end
				
				LOAD_A:begin		
					if(filt_count == (IFMAP_WIDTH**2-1)) begin
						r_write_en <= 0;
						r_read_en <= 1;
						r_raddr <= W_READ_ADDR;
						o_load_done <= 1;
						state <= IDLE;
					end else begin
						r_wdata <= i_ifmap_in;
						r_waddr <= r_waddr + 1;
						filt_count <= filt_count + 1;
						state <= LOAD_A;
					end
				end
			endcase
		end
	end
						
	assign o_pe_out = w_mac_out;

endmodule
