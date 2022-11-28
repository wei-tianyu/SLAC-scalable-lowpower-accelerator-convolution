//`timescale 1ns/1ps

module rlc_dec(
	input 			clk,
	input			rst_n,
	input			dec_bypass_en,
	input			dec_bypass_last,
	input 			core_ready,
	input 			dram_valid,
	input 	[63:0]	dram_data,
	output 			dec_valid,
	output 			dec_last,
	output 			dec_ready,
	output	[63:0]	dec_data
);

	wire [4:0] 	run_0;
	wire [4:0] 	run_1;
	wire [4:0] 	run_2;
	wire [15:0] level_0;
	wire [15:0] level_1;
	wire [15:0] level_2;
	wire 		term;

	reg [4:0] 	run_0_reg;
	reg [4:0] 	run_1_reg;
	reg [4:0] 	run_2_reg;
	reg [15:0] 	level_0_reg;
	reg [15:0] 	level_1_reg;
	reg [15:0] 	level_2_reg;
	reg 		term_reg;
	reg			data_ready;

	wire [1583:0]	dec_data_tmp_0;
	wire [1583:0]	dec_data_tmp_1;
	wire [1583:0]	dec_data_tmp_2;
	wire [1583:0]	dec_data_tmp_3;
	wire [1631:0]	dec_data_buf;


	wire tx_en;
	wire tx_done;
	reg [10:0] tx_ptr;

	reg [47:0] 	remainder_val;
	reg [1:0]	remainder_cnt;
	
	wire hold;
	reg hold_d0;
	wire hold_posedge;

	reg [6:0] curr_data_cnt;


	assign run_0 	= dram_data[63:59];
	assign run_1 	= dram_data[42:38];
	assign run_2 	= dram_data[21:17];
	assign level_0 	= dram_data[58:43];
	assign level_1 	= dram_data[37:22];
	assign level_2 	= dram_data[16:1];
	assign term 	= dram_data[0];

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			run_0_reg 		<=  5'b0;
			run_1_reg 		<=  5'b0;
			run_2_reg 		<=  5'b0;
			level_0_reg 	<=  16'b0;
			level_1_reg 	<=  16'b0;
			level_2_reg 	<=  16'b0;
			term_reg 		<=  1'b0;
			data_ready		<=	1'b0;
		end
		else if(dram_valid & dec_ready) begin
			run_0_reg 		<= run_0 	 ;
			run_1_reg 		<= run_1 	 ;
			run_2_reg 		<= run_2 	 ;
			level_0_reg 	<= level_0 	 ;
			level_1_reg 	<= level_1 	 ;
			level_2_reg 	<= level_2 	 ;
			term_reg		<= term 	 ;
			data_ready		<= 1'b1;
		end
	//	else if(tx_done | ((dram_data[63:59]+dram_data[42:38]+dram_data[21:17]+3+remainder_cnt) < 4)) begin
		else if(tx_done | run_0_reg+run_1_reg+run_2_reg==0) begin
			run_0_reg 		<=  5'b0;
			run_1_reg 		<=  5'b0;
			run_2_reg 		<=  5'b0;
			level_0_reg 	<=  16'b0;
			level_1_reg 	<=  16'b0;
			level_2_reg 	<=  16'b0;
			term_reg		<=  1'b0;
			data_ready		<=	1'b0;
		end
	end

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			remainder_val <= 48'b0;
			remainder_cnt <= 2'b0;
		end
		else if(tx_done | ((curr_data_cnt<4) & data_ready)) begin
			if(curr_data_cnt%4) begin
				if(curr_data_cnt>=4)
					remainder_val <= dec_data_buf[(tx_ptr+1)*64+:48];
				else
					remainder_val <= {level_2_reg,level_1_reg,level_0_reg};
				remainder_cnt <= curr_data_cnt%4;
			end
			else begin
				remainder_val <= 48'b0;
				remainder_cnt <= 2'b0;
			end

		end
	end



	assign hold = 	(data_ready & (curr_data_cnt%4 != 0) & (curr_data_cnt > 4)) |
					(data_ready & (tx_ptr < (curr_data_cnt/4)-1) & (curr_data_cnt > 4));

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n)
			hold_d0 <= 1'b0;
		else
			hold_d0 <= hold;
	end

	assign hold_posedge = hold & ~hold_d0;
		


		
	genvar i;
	generate
		for(i=0;i<99;i=i+1) begin
			assign dec_data_tmp_0[i*16+:16] = (i==run_0_reg) ? level_0_reg : 16'b0;
			assign dec_data_tmp_1[i*16+:16] = (i==run_0_reg+run_1_reg+1) ? level_1_reg : 16'b0;
			assign dec_data_tmp_2[i*16+:16] = (i==run_0_reg+run_1_reg+run_2_reg+2) ? level_2_reg : 16'b0;
		end
	endgenerate
		


	
	assign dec_data_tmp_3 = dec_data_tmp_2 | dec_data_tmp_1 | dec_data_tmp_0;

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) 
			tx_ptr <= 0;
		else if(tx_done)
			tx_ptr <= 11'b0;	
		else if(tx_en)
			tx_ptr <= tx_ptr + 1'b1;
	end


	always@(*) begin
		if(~term_reg)
			curr_data_cnt = run_0_reg+run_1_reg+run_2_reg+3+remainder_cnt;
		else begin
			if(level_0_reg==0 & run_1_reg==0 & level_1_reg==0 & run_2_reg==0 & level_2_reg==0) begin
				if(run_0_reg!=31)
					curr_data_cnt = run_0_reg+remainder_cnt;
				else begin
					if((run_0_reg+1+remainder_cnt)%4 == 0)	//level0 is included
						curr_data_cnt = run_0_reg+1+remainder_cnt;
					else
						curr_data_cnt = run_0_reg+remainder_cnt;
				end		
			end
			else if(level_1_reg==0 & run_2_reg==0 & level_2_reg==0) begin
				if(run_1_reg!=31)
					curr_data_cnt = run_0_reg+1+run_1_reg+remainder_cnt;
				else begin
					if((run_0_reg+1+run_1_reg+1+remainder_cnt)%4 == 0)	//level1 is included
						curr_data_cnt = run_0_reg+1+run_1_reg+1+remainder_cnt;
					else
						curr_data_cnt = run_0_reg+1+run_1_reg+remainder_cnt;
				end		
			end
			else if(level_2_reg==0) begin
				if(run_2_reg!=31)
					curr_data_cnt = run_0_reg+1+run_1_reg+1+run_2_reg+remainder_cnt;
				else begin
					if((run_0_reg+1+run_1_reg+1+run_2_reg+1+remainder_cnt)%4 == 0)	//level2 is included
						curr_data_cnt = run_0_reg+1+run_1_reg+1+run_2_reg+1+remainder_cnt;
					else
						curr_data_cnt = run_0_reg+1+run_1_reg+1+run_2_reg+remainder_cnt;
				end		
			end
			else
				curr_data_cnt = run_0_reg+run_1_reg+run_2_reg+3+remainder_cnt;
		end
	end

	assign dec_valid = dec_bypass_en ? dram_valid : tx_en; 
	assign dec_ready = dec_bypass_en ? core_ready : (core_ready ? (~data_ready | tx_done | ~hold) : ~((tx_ptr < (curr_data_cnt/4)) & data_ready));
	assign tx_en = (tx_ptr < (curr_data_cnt/4)) & core_ready & data_ready;
	assign tx_done = (tx_ptr == curr_data_cnt/4-1) & tx_en;
	assign dec_last = dec_bypass_en ? dec_bypass_last : term_reg & tx_done;
	assign dec_data = dec_bypass_en ? dram_data : dec_data_buf[tx_ptr*64+:64];
	assign dec_data_buf = 	remainder_cnt == 2'd3 ? {dec_data_tmp_3,remainder_val} 			:
							remainder_cnt == 2'd2 ? {dec_data_tmp_3,remainder_val[31:0]} 	:
							remainder_cnt == 2'd1 ? {dec_data_tmp_3,remainder_val[15:0]} 	:
							dec_data_tmp_3;

endmodule
