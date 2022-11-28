//`timescale 1ns/1ps


module rlc_enc(
	input 			clk,
	input			rst_n,
	input 			dram_ready,	
	input 			core_valid,
	input 			core_last,
	input 	[63:0]	core_data,
	output reg		enc_valid,
	output 			enc_ready,
	output reg[63:0]	enc_data
);

	parameter RUN0 = 6'b000001;
	parameter LVL0 = 6'b000010;
	parameter RUN1 = 6'b000100;
	parameter LVL1 = 6'b001000;
	parameter RUN2 = 6'b010000;
	parameter LVL2 = 6'b100000;

	reg [5:0] state;

	reg [15:0] 	lvl_0;
	reg [15:0] 	lvl_1;
	reg [15:0] 	lvl_2;
	reg [15:0] 	lvl_3;

	reg [2:0] lvl_0_idx;
	reg [2:0] lvl_1_idx;
	reg [2:0] lvl_2_idx;
	reg [2:0] lvl_3_idx;
	reg [15:0] lvl_0_reg;
	reg [15:0] lvl_1_reg;
	reg [15:0] lvl_2_reg;
	reg [4:0] run_0_reg;
	reg [4:0] run_1_reg;
	reg [4:0] run_2_reg;
	reg [4:0] run_0_reg_rollover;
	reg [4:0] run_1_reg_rollover;
	reg [4:0] run_2_reg_rollover;
	reg [15:0] lvl_0_reg_rollover;
	reg [15:0] lvl_1_reg_rollover;
	reg [15:0] lvl_2_reg_rollover;
	wire [4:0] run_0_next;
	wire [4:0] run_1_next;
	wire [4:0] run_2_next;

	reg tx_en;
	reg run_0_rollover;
	reg run_1_rollover;
	reg run_2_rollover;
	reg lvl_0_rollover;
	reg lvl_1_rollover;
	reg lvl_2_rollover;


	wire [2:0] zero_cnt;
	wire term;
	wire halt;

	reg last_ff_0;
	reg last_ff_1;

	assign zero_cnt = 	(core_data[16*0+:16]==0) +
						(core_data[16*1+:16]==0) +
						(core_data[16*2+:16]==0) +
						(core_data[16*3+:16]==0); 
	assign term = last_ff_0 & ~run_0_rollover ? 1'b1 : (last_ff_0!=last_ff_1 ? last_ff_1 : 1'b0); 

	assign halt = tx_en & ~dram_ready;
	assign enc_ready = ~(state == LVL2 & run_0_rollover & run_1_rollover & run_2_rollover &
						 lvl_0_rollover & lvl_1_rollover & lvl_2_rollover) & ~halt; //TODO not ready when last asserted
	assign enc_valid = (tx_en & ~halt) | last_ff_0 | last_ff_1;
//	assign enc_data = {run_0_reg,lvl_0_reg,run_1_reg,lvl_1_reg,run_2_reg,lvl_2_reg,term};

	
	
	always@(*) begin
		if(~term)
			enc_data = {run_0_reg,lvl_0_reg,run_1_reg,lvl_1_reg,run_2_reg,lvl_2_reg,term};
		else if(state == RUN0)
			enc_data = {run_0_reg,16'b0,5'b0,16'b0,5'b0,16'b0,term};
		else if(state == LVL0)
			enc_data = {run_0_reg,lvl_0_reg,5'b0,16'b0,5'b0,16'b0,term};
		else if(state == RUN1)
			enc_data = {run_0_reg,lvl_0_reg,run_1_reg,16'b0,5'b0,16'b0,term};
		else if(state == LVL1)
			enc_data = {run_0_reg,lvl_0_reg,run_1_reg,lvl_1_reg,5'b0,16'b0,term};
		else if(state == RUN2)
			enc_data = {run_0_reg,lvl_0_reg,run_1_reg,lvl_1_reg,run_2_reg,16'b0,term};
		else
			enc_data = {run_0_reg,lvl_0_reg,run_1_reg,lvl_1_reg,run_2_reg,lvl_2_reg,term};
	end


	always@(*) begin
		lvl_0 = 16'b0;
		lvl_1 = 16'b0;
		lvl_2 = 16'b0;
		lvl_3 = 16'b0;
		lvl_0_idx = 3'd4;
		lvl_1_idx = 3'd4;
		lvl_2_idx = 3'd4;
		lvl_3_idx = 3'd4;
		
		if(core_valid & enc_ready) begin
			for(int i=0;i<4;i++) begin
				if(core_data[16*i+:16] != 16'b0) begin
					if(lvl_0_idx == 3'd4) begin
						lvl_0 = core_data[16*i+:16];
						lvl_0_idx = i;
					end
					else if(lvl_1_idx == 3'd4) begin
						lvl_1 = core_data[16*i+:16];
						lvl_1_idx = i;
					end			
					else if(lvl_2_idx == 3'd4) begin
						lvl_2 = core_data[16*i+:16];
						lvl_2_idx = i;
					end				
					else if(lvl_3_idx == 3'd4) begin
						lvl_3 = core_data[16*i+:16];
						lvl_3_idx = i;
					end
				end
			end
		end
	end


	assign run_0_next = run_0_rollover ? run_0_reg_rollover : run_0_reg;
	assign run_1_next = run_1_rollover ? run_1_reg_rollover : run_1_reg;
	assign run_2_next = run_2_rollover ? run_2_reg_rollover : run_2_reg;


	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			last_ff_0 <= 1'b0;
		end
		else begin
			if(core_valid & enc_ready)
				last_ff_0 <= core_last;
			else if(dram_ready)
				last_ff_0 <= 1'b0;
		end
	end

	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			last_ff_1 <= 1'b0;
		end
		else begin
			if(last_ff_0 & run_0_rollover) 
				last_ff_1 <= 1'b1;
			else if(dram_ready)
				last_ff_1 <= 1'b0;
		end
	end


	always@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			state <= RUN0;
			run_0_reg <= 5'b0;
			run_1_reg <= 5'b0;
			run_2_reg <= 5'b0;
			lvl_0_reg <= 16'b0;
			lvl_1_reg <= 16'b0;
			lvl_2_reg <= 16'b0;
			tx_en <= 1'b0;
			run_0_rollover <= 1'b0;
			run_1_rollover <= 1'b0;
			run_2_rollover <= 1'b0;
			lvl_0_rollover <= 1'b0;
			lvl_1_rollover <= 1'b0;
			lvl_2_rollover <= 1'b0;
			run_0_reg_rollover <= 5'b0;
			run_1_reg_rollover <= 5'b0;
			run_2_reg_rollover <= 5'b0;
			lvl_0_reg_rollover <= 16'b0;
			lvl_1_reg_rollover <= 16'b0;
			lvl_2_reg_rollover <= 16'b0;
		end
		else if(last_ff_0 & enc_valid & dram_ready) begin  //TODO handle rollover != 0
			if(run_0_rollover) begin
				run_0_reg <= run_0_rollover ? run_0_reg_rollover : 5'b0;
				run_1_reg <= run_1_rollover ? run_1_reg_rollover : 5'b0;
				run_2_reg <= run_2_rollover ? run_2_reg_rollover : 5'b0;
				lvl_0_reg <= lvl_0_rollover ? lvl_0_reg_rollover : 16'b0;
				lvl_1_reg <= lvl_1_rollover ? lvl_1_reg_rollover : 16'b0;
				lvl_2_reg <= lvl_2_rollover ? lvl_2_reg_rollover : 16'b0;
				tx_en <= 1'b1;				
			end
			else begin
				state <= RUN0;
				run_0_reg <= 5'b0;
				run_1_reg <= 5'b0;
				run_2_reg <= 5'b0;
				lvl_0_reg <= 16'b0;
				lvl_1_reg <= 16'b0;
				lvl_2_reg <= 16'b0;
				tx_en <= 1'b0;
				run_0_rollover <= 1'b0;
				run_1_rollover <= 1'b0;
				run_2_rollover <= 1'b0;
				lvl_0_rollover <= 1'b0;
				lvl_1_rollover <= 1'b0;
				lvl_2_rollover <= 1'b0;
				run_0_reg_rollover <= 5'b0;
				run_1_reg_rollover <= 5'b0;
				run_2_reg_rollover <= 5'b0;
				lvl_0_reg_rollover <= 16'b0;
				lvl_1_reg_rollover <= 16'b0;
				lvl_2_reg_rollover <= 16'b0;
			end
		end		
		else if(last_ff_1 & enc_valid & dram_ready) begin
			state <= RUN0;
			run_0_reg <= 5'b0;
			run_1_reg <= 5'b0;
			run_2_reg <= 5'b0;
			lvl_0_reg <= 16'b0;
			lvl_1_reg <= 16'b0;
			lvl_2_reg <= 16'b0;
			tx_en <= 1'b0;
			run_0_rollover <= 1'b0;
			run_1_rollover <= 1'b0;
			run_2_rollover <= 1'b0;
			lvl_0_rollover <= 1'b0;
			lvl_1_rollover <= 1'b0;
			lvl_2_rollover <= 1'b0;
			run_0_reg_rollover <= 5'b0;
			run_1_reg_rollover <= 5'b0;
			run_2_reg_rollover <= 5'b0;
			lvl_0_reg_rollover <= 16'b0;
			lvl_1_reg_rollover <= 16'b0;
			lvl_2_reg_rollover <= 16'b0;
		end
		else if(~halt) begin 
			run_0_reg <= run_0_next;
			run_1_reg <= run_1_next; 
			run_2_reg <= run_2_next; 
			lvl_0_reg <= lvl_0_rollover ? lvl_0_reg_rollover : lvl_0_reg; 
			lvl_1_reg <= lvl_1_rollover ? lvl_1_reg_rollover : lvl_1_reg; 
			lvl_2_reg <= lvl_2_rollover ? lvl_2_reg_rollover : lvl_2_reg;
			run_0_rollover <= 1'b0; 
			run_1_rollover <= 1'b0; 
			run_2_rollover <= 1'b0; 
			lvl_0_rollover <= 1'b0; 
			lvl_1_rollover <= 1'b0; 
			lvl_2_rollover <= 1'b0; 
			tx_en <= enc_ready ? 1'b0 : 1'b1;//case where the leftover can be grouped as one tx
			state <= enc_ready ? state : RUN0;

			case(state)
				RUN0: begin
					if(core_valid & enc_ready) begin
						if(zero_cnt == 4) begin		//4*16bit input are all zero
							if(run_0_next + 4 == 31) begin
								state <= RUN0;
								run_0_reg <= 31;
							end
							else if(run_0_next + 4 < 31) begin
								state <= RUN0;
								run_0_reg <= run_0_next + 4;
							end
							else begin	
								state <= RUN1;
								run_0_reg <= 31;
								lvl_0_reg <= 0;
								run_1_reg <= run_0_next + 3 - 31;
							end
						end
						else if(zero_cnt == 3) begin		//1 non zero 16bit number
							if(run_0_next + lvl_0_idx <= 31) begin
								run_0_reg <= run_0_next + lvl_0_idx;
								lvl_0_reg <= lvl_0;
								run_1_reg <= 3 - lvl_0_idx;						
								if(lvl_0_idx != 3)	//need to move to run2
									state <= RUN1;
								else
									state <= LVL0;
							end
							else begin 
								run_0_reg <= 31;
								lvl_0_reg <= 0;
								run_1_reg <= run_0_next + lvl_0_idx - 32; //TODO
								lvl_1_reg <= lvl_0;
								if(lvl_0_idx != 3) begin	//need to move to run2
									state <= RUN2;
									run_2_reg <= 3 - lvl_0_idx;
								end
								else
									state <= LVL1;
							end
						end
						else if(zero_cnt == 2) begin		//2 non zero 16bit number
							if(run_0_next + lvl_0_idx <= 31) begin
								run_0_reg <= run_0_next + lvl_0_idx;
								lvl_0_reg <= lvl_0;
								run_1_reg <= lvl_1_idx - lvl_0_idx - 1;
								lvl_1_reg <= lvl_1;
								if(lvl_1_idx != 3) begin	//need to move to run2
									state <= RUN2;
									run_2_reg <= 3 - lvl_1_idx;
								end
								else
									state <= LVL1;
							end
							else begin
								run_0_reg <= 31;
								lvl_0_reg <= 0;
								run_1_reg <= run_0_next + lvl_0_idx - 32;		
								lvl_1_reg <= lvl_0;
								run_2_reg <= lvl_1_idx - lvl_0_idx - 1;		
								lvl_2_reg <= lvl_1;
								tx_en <= 1'b1;
								if(lvl_1_idx != 3) begin	//need to move to run2
									state <= RUN0;
									run_0_reg_rollover <= 3 - lvl_1_idx;
									run_0_rollover <= 1;
								end
								else begin
									state <= LVL2;
								end
							end 
						end
						else if(zero_cnt == 1) begin	//3 non zero 16bit number
							if(run_0_next + lvl_0_idx <= 31) begin
								run_0_reg <= run_0_next + lvl_0_idx;
								lvl_0_reg <= lvl_0;
								run_1_reg <= lvl_1_idx - lvl_0_idx - 1;
								lvl_1_reg <= lvl_1;
								run_2_reg <= lvl_2_idx - lvl_1_idx - 1;
								lvl_2_reg <= lvl_2;
								tx_en <= 1'b1;
								if(lvl_2_idx != 3) begin	//need to move to run0
									state <= RUN0;
									run_0_reg_rollover <= 3 - lvl_2_idx;
									run_0_rollover <= 1'b1;
								end
								else
									state <= LVL2;
							end
							else begin
								run_0_reg <=31;
								lvl_0_reg <= 0;
								run_1_reg <= 0;	
								lvl_1_reg <= lvl_0;
								run_2_reg <= 0;
								lvl_2_reg <= lvl_1;
								run_0_reg_rollover <= 0;
								lvl_0_reg_rollover <= lvl_2;
								run_0_rollover <= 1'b1;
								lvl_0_rollover <= 1'b1;
								tx_en <= 1'b1;
								state <= LVL0;
							end
						end
						else if(zero_cnt == 0) begin	//4 non zero 16bit number
							state <= LVL0;
							run_0_reg <= run_0_next + lvl_0_idx;
							lvl_0_reg <= lvl_0;
							run_1_reg <= lvl_1_idx - lvl_0_idx - 1;
							lvl_1_reg <= lvl_1;
							run_2_reg <= lvl_2_idx - lvl_1_idx - 1;
							lvl_2_reg <= lvl_2;
							run_0_reg_rollover <= 0;
							lvl_0_reg_rollover <= lvl_3; 
							run_0_rollover <= 1'b1;
							lvl_0_rollover <= 1'b1;
							tx_en <= 1'b1;
						end	
					end
				end

				LVL0: begin
					if(core_valid & enc_ready) begin
						if(zero_cnt == 4) begin		//4*16bit input are all zero
							state <= RUN1;
							run_1_reg <= 4;
						end
						else if(zero_cnt == 3) begin		//1 non zero 16bit number
							run_1_reg <= lvl_0_idx;
							lvl_1_reg <= lvl_0;
							run_2_reg <= 3 - lvl_0_idx;
							if(lvl_0_idx != 3)	//need to move to run2
								state <= RUN2;
							else
								state <= LVL1;	
						end
						else if(zero_cnt == 2) begin		//2 non zero 16bit number
							run_1_reg <= lvl_0_idx;
							lvl_1_reg <= lvl_0;
							run_2_reg <= lvl_1_idx - lvl_0_idx - 1;
							lvl_2_reg <= lvl_1;
							tx_en <= 1'b1;
							if(lvl_1_idx != 3) begin	//need to move to run0
								state <= RUN0;
								run_0_reg_rollover <= 3 - lvl_1_idx;
								run_0_rollover  <= 1'b1;
							end
							else
								state <= LVL2;
						end
						else if(zero_cnt == 1) begin	//3 non zero 16bit number
							run_1_reg <= lvl_0_idx;
							lvl_1_reg <= lvl_0;
							run_2_reg <= lvl_1_idx - lvl_0_idx - 1;
							lvl_2_reg <= lvl_1;
							run_0_reg_rollover <= lvl_2_idx - lvl_1_idx - 1;
							lvl_0_reg_rollover <= lvl_2;
							run_0_rollover <= 1'b1;
							lvl_0_rollover <= 1'b1;
							tx_en <= 1'b1;
							if(lvl_2_idx != 3) begin	//need to move to run0
								state <= RUN1;
								run_1_reg_rollover <= 3 - lvl_2_idx;
								run_1_rollover <= 1'b1;
							end
							else
								state <= LVL0;
						end
						else if(zero_cnt == 0) begin	//4 non zero 16bit number
							state <= LVL1;
							run_1_reg <= lvl_0_idx;
							lvl_1_reg <= lvl_0;
							run_2_reg <= lvl_1_idx - lvl_0_idx - 1;
							lvl_2_reg <= lvl_1;
							run_0_reg_rollover <= 0;
							lvl_0_reg_rollover <= lvl_2;
							run_1_reg_rollover <= 0;
							lvl_1_reg_rollover <= lvl_3; 
							tx_en <= 1'b1;
							run_0_rollover <= 1'b1;
							lvl_0_rollover <= 1'b1;
							run_1_rollover <= 1'b1;
							lvl_1_rollover <= 1'b1;
						end
					end	
				end		

				RUN1: begin
					if(core_valid & enc_ready) begin
						if(zero_cnt == 4) begin		//4*16bit input are all zero
							if(run_1_next + 4 == 31) begin
								state <= RUN1;
								run_1_reg <= 31;
							end
							else if(run_1_next + 4 < 31) begin
								state <= RUN1;
								run_1_reg <= run_1_next + 4;
							end
							else begin
								state <= RUN2;
								run_1_reg <= 31;
								lvl_1_reg <= 0;
								run_2_reg <= run_1_next + 3 - 31;
							end
						end
						/***********************************************************/
						//TODO
						else if(zero_cnt == 3) begin		//1 non zero 16bit number
							if(run_1_next + lvl_0_idx <= 31) begin	//no overflow
								run_1_reg <= run_1_next + lvl_0_idx;	
								lvl_1_reg <= lvl_0;
								run_2_reg <= 3 - lvl_0_idx;
								if(lvl_0_idx != 3)	//need to move to run2
									state <= RUN2;
								else
									state <= LVL1;		
							end
							else begin
								run_1_reg <= 31;
								lvl_1_reg <= 0;
								run_2_reg <= run_1_next + lvl_0_idx - 31 -1;		
								lvl_2_reg <= lvl_0;
								tx_en <= 1'b1;
								if(lvl_0_idx != 3) begin	//need to move to run2
									state <= RUN0;
									run_0_reg_rollover <= 3 - lvl_0_idx; 
									run_0_rollover <= 1'b1;
								end
								else
									state <= LVL2;		
							end				
						end
						/***********************************************************/
						else if(zero_cnt == 2) begin		//2 non zero 16bit number
							if(run_1_next + lvl_0_idx <= 31) begin	//no overflow
								run_1_reg <= run_1_next + lvl_0_idx;
								lvl_1_reg <= lvl_0;
								run_2_reg <= lvl_1_idx - lvl_0_idx - 1;
								lvl_2_reg <= lvl_1;
								tx_en <= 1'b1;
								if(lvl_1_idx != 3) begin	//need to move to run2
									state <= RUN0;
									run_0_reg_rollover <= 3 - lvl_1_idx;
									run_0_rollover <= 1'b1;
								end
								else
									state <= LVL2;
							end
							else begin
								run_1_reg <= 31;
								lvl_1_reg <= 0;
								run_2_reg <= run_1_next + lvl_0_idx - 32;		
								lvl_2_reg <= lvl_0; //TODO
								tx_en <= 1'b1;
								run_0_reg_rollover <= lvl_1_idx - lvl_0_idx - 1;
								lvl_0_reg_rollover <= lvl_1;
								run_0_rollover <= 1'b1;
								lvl_0_rollover <= 1'b1;	
								if(lvl_1_idx != 3) begin
									state <= RUN1;
									run_1_reg_rollover <= 3 - lvl_1_idx;
									run_1_rollover <= 1'b1;
								end
								else begin
									state <= LVL0;
								end
							end
						end
						else if(zero_cnt == 1) begin	//3 non zero 16bit number
							if(run_1_next + lvl_0_idx <= 31) begin	//no overflow
								run_1_reg <= run_1_next + lvl_0_idx;
								lvl_1_reg <= lvl_0;
								run_2_reg <= lvl_1_idx - lvl_0_idx - 1;
								lvl_2_reg <= lvl_1;
								run_0_reg_rollover <= lvl_2_idx - lvl_1_idx -1;
								//run_0_reg_rollover <= 0;
								lvl_0_reg_rollover <= lvl_2;
								run_0_rollover <= 1'b1;
								lvl_0_rollover <= 1'b1;
								tx_en <= 1'b1;
								if(lvl_2_idx != 3) begin	//need to move to run0
									state <= RUN1;
									run_1_reg_rollover <= 3 - lvl_2_idx;
									run_1_rollover <= 1'b1;
								end
								else
									state <= LVL0;
							end
							else begin
								run_1_reg <=31;
								lvl_1_reg <= 0;
								run_2_reg <= 0;	
								lvl_2_reg <= lvl_0;
								run_0_reg_rollover <= 0;
								lvl_0_reg_rollover <= lvl_1;
								run_1_reg_rollover <= 0;
								lvl_1_reg_rollover <= lvl_2;
								run_0_rollover <= 1'b1;
								lvl_0_rollover <= 1'b1;
								run_1_rollover <= 1'b1;
								lvl_1_rollover <= 1'b1;
								tx_en <= 1'b1;
								state <= LVL1;
							end
						end
						else if(zero_cnt == 0) begin	//4 non zero 16bit number
							state <= LVL1;
							run_1_reg <= run_1_next + lvl_0_idx;
							lvl_1_reg <= lvl_0;
							run_2_reg <= lvl_1_idx - lvl_0_idx - 1;
							lvl_2_reg <= lvl_1;
							run_0_reg_rollover <= 0;
							lvl_0_reg_rollover <= lvl_2;
							run_1_reg_rollover <= 0;
							lvl_1_reg_rollover <= lvl_3; 
							tx_en <= 1'b1;
							run_0_rollover <= 1'b1;
							lvl_0_rollover <= 1'b1;
							run_1_rollover <= 1'b1;
							lvl_1_rollover <= 1'b1;
						end
					end	
				end

				LVL1: begin
					if(core_valid & enc_ready) begin
						if(zero_cnt == 4) begin		//4*16bit input are all zero
							state <= RUN2;
							run_2_reg <= 4;
						end
						else if(zero_cnt == 3) begin		//1 non zero 16bit number
							run_2_reg <= lvl_0_idx;
							lvl_2_reg <= lvl_0;
							tx_en <= 1'b1;
							if(lvl_0_idx != 3) begin	//need to move to run2
								state <= RUN0;
								run_0_reg_rollover <= 3 - lvl_0_idx;
								run_0_rollover <= 1'b1;
							end
							else
								state <= LVL2;	
						end
						else if(zero_cnt == 2) begin		//2 non zero 16bit number
							run_2_reg <= lvl_0_idx;
							lvl_2_reg <= lvl_0;
							run_0_reg_rollover <= lvl_1_idx - lvl_0_idx - 1;
							lvl_0_reg_rollover <= lvl_1;
							tx_en <= 1'b1;
							run_0_rollover <= 1'b1;
							lvl_0_rollover <= 1'b1;
							if(lvl_1_idx != 3) begin	//need to move to run0
								state <= RUN1;
								run_1_reg_rollover <= 3 - lvl_1_idx;
								run_1_rollover <= 1'b1;
							end
							else
								state <= LVL0;
						end
						else if(zero_cnt == 1) begin	//3 non zero 16bit number
							run_2_reg <= lvl_0_idx;
							lvl_2_reg <= lvl_0;
							run_0_reg_rollover <= lvl_1_idx - lvl_0_idx - 1;
							lvl_0_reg_rollover <= lvl_1;
							run_1_reg_rollover <= lvl_2_idx - lvl_1_idx - 1;
							lvl_1_reg_rollover <= lvl_2;
							tx_en <= 1'b1;
							run_0_rollover <= 1'b1;
							lvl_0_rollover <= 1'b1;
							run_1_rollover <= 1'b1;
							lvl_1_rollover <= 1'b1;
							if(lvl_2_idx != 3) begin	//need to move to run1
								state <= RUN2;
								run_2_reg_rollover <= 3 - lvl_2_idx;
								run_2_rollover <= 1'b1;
							end
							else
								state <= LVL1;
						end
						else if(zero_cnt == 0) begin	//4 non zero 16bit number
							state <= LVL2;
							run_2_reg <= lvl_0_idx;
							lvl_2_reg <= lvl_0;
							run_0_reg_rollover <= lvl_1_idx - lvl_0_idx - 1;
							lvl_0_reg_rollover <= lvl_1;
							run_1_reg_rollover <= 0;
							lvl_1_reg_rollover <= lvl_2;
							run_2_reg_rollover <= 0;
							lvl_2_reg_rollover <= lvl_3; 
							tx_en <= 1'b1;
							run_0_rollover <= 1'b1;
							lvl_0_rollover <= 1'b1;
							run_1_rollover <= 1'b1;
							lvl_1_rollover <= 1'b1;
							run_2_rollover <= 1'b1;
							lvl_2_rollover <= 1'b1;
						end
					end	
				end

				RUN2: begin
					if(core_valid & enc_ready) begin
						if(zero_cnt == 4) begin		//4*16bit input are all zero
							if(run_2_next + 4 == 31) begin
								state <= RUN2;
								run_2_reg <= 31;
							end
							else if(run_2_next + 4 < 31) begin
								state <= RUN2;
								run_2_reg <= run_2_next + 4;
							end
							else begin
								tx_en <= 1'b1;
								run_0_rollover <= 1'b1;
								state <= RUN0;
								run_2_reg <= 31;
								lvl_2_reg <= 0;
								run_0_reg_rollover <= run_2_next + 3 - 31;
							end
						end
						else if(zero_cnt == 3) begin		//1 non zero 16bit number
							if(run_2_next + lvl_0_idx <= 31) begin	//no overflow
								run_2_reg <= run_2_next + lvl_0_idx;
								lvl_2_reg <= lvl_0;
								tx_en <= 1'b1;
								if(lvl_0_idx != 3) begin	//need to move to run2
									state <= RUN0;
									run_0_rollover <= 1'b1;
									run_0_reg_rollover <= 3 - lvl_0_idx;
								end						
								else
									state <= LVL2;
							end
							else begin
								run_2_reg <= 31;
								lvl_2_reg <= 0;
								tx_en <= 1'b1;
								if(lvl_0_idx != 3) begin	//need to move to run2
									state <= RUN1;
									run_0_reg_rollover <= run_2_next + lvl_0_idx - 32; 
									lvl_0_reg_rollover <= lvl_0; 
									run_1_reg_rollover <= 3 - lvl_0_idx; 
									run_0_rollover <= 1'b1;
									lvl_0_rollover <= 1'b1;
									run_1_rollover <= 1'b1;
								end
								else begin
									state <= LVL0;	
									run_0_reg_rollover <= run_2_next + lvl_0_idx - 32; 
									lvl_0_reg_rollover <= lvl_0; 
									run_0_rollover <= 1'b1;
									lvl_0_rollover <= 1'b1;
								end
							end
						end
						else if(zero_cnt == 2) begin		//2 non zero 16bit number
							if(run_2_next + lvl_0_idx <= 31) begin	//no overflow
								run_2_reg <= run_2_next + lvl_0_idx;
								lvl_2_reg <= lvl_0;
								run_0_reg_rollover <= lvl_1_idx - lvl_0_idx - 1;
								//run_0_reg_rollover <= 0;
								lvl_0_reg_rollover <= lvl_1;
								tx_en <= 1'b1;
								run_0_rollover <= 1'b1;
								lvl_0_rollover <= 1'b1;
								if(lvl_1_idx != 3) begin	//need to move to run2
									state <= RUN1;
									run_1_reg_rollover <= 3 - lvl_1_idx;
									run_1_rollover <= 1'b1;
								end
								else
									state <= LVL0;
							end
							else begin
								run_2_reg <=31;
								lvl_2_reg <= 0;
								run_0_reg_rollover <= run_2_next + lvl_0_idx - 32;	
								lvl_0_reg_rollover <= lvl_0;
								run_1_reg_rollover <= lvl_1_idx - lvl_0_idx - 1;
								lvl_1_reg_rollover <= lvl_1;
								run_0_rollover <= 1'b1;
								lvl_0_rollover <= 1'b1;
								run_1_rollover <= 1'b1;
								lvl_1_rollover <= 1'b1;
								tx_en <= 1'b1;
								if(lvl_1_idx != 3) begin	//need to move to run2
									state <= RUN2;
									run_2_reg_rollover <= 3 - lvl_1_idx;
									run_2_rollover <= 1'b1;
								end
								else begin
									state <= LVL1;
								end
							end
						end	
						else if(zero_cnt == 1) begin	//3 non zero 16bit number
							if(run_2_next + lvl_0_idx <= 31) begin	//no overflow
								run_2_reg <= run_2_next + lvl_0_idx;
								lvl_2_reg <= lvl_0;
								run_0_reg_rollover <= lvl_1_idx - lvl_0_idx -1;
								lvl_0_reg_rollover <= lvl_1;
								run_1_reg_rollover <= lvl_2_idx - lvl_1_idx -1;
								lvl_1_reg_rollover <= lvl_2;
								run_0_rollover <= 1'b1;
								lvl_0_rollover <= 1'b1;
								run_1_rollover <= 1'b1;
								lvl_1_rollover <= 1'b1;
								tx_en <= 1'b1;
								if(lvl_2_idx != 3) begin	//need to move to run0
									state <= RUN2;
									run_2_reg_rollover <= 3 - lvl_2_idx;
									run_2_rollover <= 1'b1;
								end
								else
									state <= LVL1;
							end
							else begin
								run_2_reg <=31;
								lvl_2_reg <= 0;
								run_0_reg_rollover <= 0;	
								lvl_0_reg_rollover <= lvl_0;
								run_1_reg_rollover <= 0;
								lvl_1_reg_rollover <= lvl_1;
								run_2_reg_rollover <= 0;
								lvl_2_reg_rollover <= lvl_2;
								run_0_rollover <= 1'b1;
								lvl_0_rollover <= 1'b1;
								run_1_rollover <= 1'b1;
								lvl_1_rollover <= 1'b1;
								run_2_rollover <= 1'b1;
								lvl_2_rollover <= 1'b1;
								tx_en <= 1'b1;
								state <= LVL2;
							end	
						end 	
						else if(zero_cnt == 0) begin	//4 non zero 16bit number
							state <= LVL2;
							run_2_reg <= run_2_next + lvl_0_idx;
							lvl_2_reg <= lvl_0;
							run_0_reg_rollover <= 0;
							lvl_0_reg_rollover <= lvl_1;
							run_1_reg_rollover <= 0;
							lvl_1_reg_rollover <= lvl_2;
							run_2_reg_rollover <= 0;
							lvl_2_reg_rollover <= lvl_3; 
							tx_en <= 1'b1;
							run_0_rollover <= 1'b1;
							lvl_0_rollover <= 1'b1;
							run_1_rollover <= 1'b1;
							lvl_1_rollover <= 1'b1;
							run_2_rollover <= 1'b1;
							lvl_2_rollover <= 1'b1;
						end
					end	
				end

				LVL2: begin
					if(core_valid & enc_ready) begin
						run_0_reg <= 5'b0;
						run_1_reg <= 5'b0;
						run_2_reg <= 5'b0;
						lvl_0_reg <= 16'b0;
						lvl_1_reg <= 16'b0;
						lvl_2_reg <= 16'b0;
                    	
						if(zero_cnt == 4) begin		//4*16bit input are all zero
							state <= RUN0;
							run_0_reg <= 4;
						end
						else if(zero_cnt == 3) begin		//1 non zero 16bit number
							run_0_reg <= lvl_0_idx;
							lvl_0_reg <= lvl_0;
							if(lvl_0_idx != 3) begin	//need to move to run2
								state <= RUN1;
								run_1_reg <= 3 - lvl_0_idx;						
							end
							else
								state <= LVL0;	
						end
						else if(zero_cnt == 2) begin		//2 non zero 16bit number
							run_0_reg <= lvl_0_idx;
							lvl_0_reg <= lvl_0;
							run_1_reg <= lvl_1_idx - lvl_0_idx - 1;
							lvl_1_reg <= lvl_1;
							if(lvl_1_idx != 3) begin	//need to move to run0
								state <= RUN2;
								run_2_reg <= 3 - lvl_1_idx;
							end
							else
								state <= LVL1;
						end
						else if(zero_cnt == 1) begin	//3 non zero 16bit number
							run_0_reg <= lvl_0_idx;
							lvl_0_reg <= lvl_0;
							run_1_reg <= lvl_1_idx - lvl_0_idx - 1;
							lvl_1_reg <= lvl_1;
							run_2_reg <= lvl_2_idx - lvl_1_idx - 1;
							lvl_2_reg <= lvl_2;
							tx_en <= 1'b1;
							if(lvl_2_idx != 3) begin	//need to move to run1
								state <= RUN0;
								run_0_rollover <= 1'b1;
								run_0_reg_rollover <= 3 - lvl_2_idx;
							end
							else
								state <= LVL2;
						end
						else if(zero_cnt == 0) begin	//4 non zero 16bit number
							state <= LVL0;
							run_0_reg <= 0;
							lvl_0_reg <= lvl_0;
							run_1_reg <= 0;
							lvl_1_reg <= lvl_1;
							run_2_reg <= 0;
							lvl_2_reg <= lvl_2;
							run_0_reg_rollover <= 0;
							lvl_0_reg_rollover <= lvl_3; 
							tx_en <= 1'b1;
							run_0_rollover <= 1'b1;
							lvl_0_rollover <= 1'b1;
						end	
					end	
				end
			endcase
		end
	end


endmodule
