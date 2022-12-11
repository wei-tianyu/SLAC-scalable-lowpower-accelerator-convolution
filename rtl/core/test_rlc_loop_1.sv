//`timescale 1ns/1ps


module testbench();

	logic			clk;
	logic			rst_n;
	logic 	[63:0]	dram_data;
	logic			dram_valid;
	logic			dram_last;
	logic			dram_ready;
	logic 	[63:0]	enc_data;
	logic			enc_valid;
	logic			enc_ready;
	logic	[63:0]	dec_data;
	logic			dec_valid;
	logic			dec_last;
	logic			dec_ready;
	logic			dec_bypass_en;
	logic			dec_bypass_last;

	bit [63:0] tx_queue[$];
	bit [63:0] rx_queue[$];
	bit [63:0] expect_result;
	bit [63:0] actual_result;
	int err_cnt;
   	int tx_cnt = 0;
	int frame_size = 1000;
	
	int all_zero_cnt 		= 10000;  
	int fully_random_cnt 	= 10000;  
	int less_zero_cnt 		= 2000000; 
	int half_zero_cnt 		= 2000000;
	int more_zero_cnt 		= 2000000;


`ifdef SYN
	initial $sdf_annotate("../../syn/rlc_dec/rlc_dec.syn.sdf", u_rlc_dec);
   	initial $sdf_annotate("../../syn/rlc_enc/rlc_enc.syn.sdf", u_rlc_enc);
   	initial begin
		all_zero_cnt 		= 10000;   	
		fully_random_cnt 	= 10000;   	
		less_zero_cnt 		= 200000;	
		half_zero_cnt 		= 200000;
		more_zero_cnt 		= 200000;
	end
`endif
   
`ifdef APR
   	initial $sdf_annotate("../../apr/rlc_dec/data/rlc_dec.apr.sdf", u_rlc_dec,,, "MAXIMUM");
   	initial $sdf_annotate("../../apr/rlc_enc/data/rlc_enc.apr.sdf", u_rlc_enc,,, "MAXIMUM");
   	initial begin
		all_zero_cnt 		= 10000;   	
		fully_random_cnt 	= 10000;   	
		less_zero_cnt 		= 200000;	
		half_zero_cnt 		= 200000;
		more_zero_cnt 		= 200000;
	end
`endif

	rlc_dec u_rlc_dec(
		.clk				(clk),
		.rst_n				(rst_n),
		.dec_bypass_en		(dec_bypass_en),
		.dec_bypass_last	(dec_bypass_last),
		.dram_valid			(enc_valid),
		.core_ready 		(dram_ready),
		.dram_data			(enc_data),
		.dec_valid			(dec_valid),
		.dec_last			(dec_last),
		.dec_ready			(dec_ready),
		.dec_data			(dec_data)
	);


	rlc_enc u_rlc_enc(
		.clk				(clk),
		.rst_n				(rst_n),
		.dram_ready			(dec_ready),
		.core_valid 		(dram_valid),
		.core_last  		(dram_last),
		.core_data			(dram_data),
		.enc_valid			(enc_valid),
		.enc_ready			(enc_ready),
		.enc_data			(enc_data)
	);

	always begin
		#5;
		clk=~clk;
	end


    class dram_item;
    	rand bit [15:0] block_0;
    	rand bit [15:0] block_1;
    	rand bit [15:0] block_2;
    	rand bit [15:0] block_3;
		rand bit valid;
		rand bit ready;

		function void print(string tag="");
			$display(	"T=%0t	[%s] enc_in = %h", 
						$time, tag, {block_3,block_2,block_1,block_0});
		endfunction

		function bit [63:0] send_data();
			return {block_3,block_2,block_1,block_0};
		endfunction

    endclass

	covergroup cov;
		coverpoint my_dram_item.block_0{
			bins zero 		= {0};
			bins non_zero 	= {[1:$]};
		}	
		coverpoint my_dram_item.block_1{
			bins zero 		= {0};
			bins non_zero 	= {[1:$]};
		}	
		coverpoint my_dram_item.block_2{
			bins zero 		= {0};
			bins non_zero 	= {[1:$]};
		}
		coverpoint my_dram_item.block_3{
			bins zero 		= {0};
			bins non_zero 	= {[1:$]};
		}

		coverpoint u_rlc_enc.state{
			bins state_run_0	= {6'b000001};
			bins state_lvl_0	= {6'b000010};
			bins state_run_1	= {6'b000100};
			bins state_lvl_1	= {6'b001000};
			bins state_run_2	= {6'b010000};
			bins state_lvl_2	= {6'b100000};
		}
	//	coverpoint u_rlc_enc.run_0_reg;
	//	coverpoint u_rlc_enc.run_1_reg;
	//	coverpoint u_rlc_enc.run_2_reg;

		cross my_dram_item.block_0, my_dram_item.block_1, my_dram_item.block_2, my_dram_item.block_3, u_rlc_enc.state;
	endgroup

	dram_item my_dram_item;
	cov my_cov;

	//initial begin
	//	forever begin
	//		@(posedge clk);
	//		#1 dram_ready = $random();
	//	end
	//end

	initial begin
	//	$dumpvars;
	//	$monitor("Time:%4.0f run0:%d run1:%d run2:%d lvl0:%h lvl1:%h lvl2:%h valid:%b st:%b cnt:%0d ready:%b",
	//		$time,	u_rlc_enc.run_0_reg,u_rlc_enc.run_1_reg,u_rlc_enc.run_2_reg,
	//				u_rlc_enc.lvl_0_reg,u_rlc_enc.lvl_1_reg,u_rlc_enc.lvl_2_reg, 
	//				enc_valid,u_rlc_enc.state,4-u_rlc_enc.zero_cnt,u_rlc_enc.enc_ready
	//	);	
		my_dram_item = new();
		my_cov = new();
		
		clk=0;
		rst_n=0;
		dram_data = 64'h0;
		dram_valid = 0;
		dram_last = 0;
		dram_ready = 1;
		dec_bypass_en = 0;
		dec_bypass_last = 0;
		#10;
		rst_n=1;
		#10;


		while(tx_cnt < all_zero_cnt) begin
			@(posedge clk);
			if(enc_ready&dram_valid) begin
				my_cov.sample();
				tx_queue.push_front(dram_data);
				my_dram_item.print("zero run");
				tx_cnt++;
				#1; dram_last = 0;
				if(tx_cnt == all_zero_cnt)
					dram_valid = 0;
				if(tx_cnt%frame_size == 0 & tx_cnt!=0) begin
					dram_valid = 0;
					repeat(20) @(posedge clk);
				end				
			end
			if(enc_ready & tx_cnt < all_zero_cnt) begin
				#1;
				dram_valid = 1;
				assert(my_dram_item.randomize() with {
					block_0 == 16'b0;
					block_1 == 16'b0;
					block_2 == 16'b0;
					block_3 == 16'b0;
				});
				dram_data = my_dram_item.send_data();
				if((tx_cnt+1)%frame_size == 0)
					dram_last = 1;
				else
					dram_last = 0;				
			end
		end
		tx_cnt = 0;
		@(posedge clk); 
		#1;
		dram_valid = 0;
		#500;


		while(tx_cnt < fully_random_cnt) begin
			@(posedge clk);
			if(enc_ready&dram_valid) begin
				my_cov.sample();
				tx_queue.push_front(dram_data);
				my_dram_item.print("fully random");
				tx_cnt++;
				#1;
				dram_last = 0;
				if(tx_cnt == fully_random_cnt)
					dram_valid = 0;
				if(tx_cnt%frame_size == 0 & tx_cnt!=0) begin
					dram_valid = 0;
					repeat(20) @(posedge clk);
				end
			end
			if(enc_ready & tx_cnt < fully_random_cnt) begin
				#1;
				dram_valid = 1;
				assert(my_dram_item.randomize() with {
				});
				dram_data = my_dram_item.send_data();
				if((tx_cnt+1)%frame_size == 0)
					dram_last = 1;
				else
					dram_last = 0;
			end
		end
		tx_cnt = 0;
		@(posedge clk); 
		#1;
		dram_valid = 0;
		#500;


		while(tx_cnt < less_zero_cnt) begin
			@(posedge clk);
			if(enc_ready&dram_valid) begin
				my_cov.sample();
				tx_queue.push_front(dram_data);
				my_dram_item.print("10% zero");
				tx_cnt++;
				#1;
				dram_last = 0;
				if(tx_cnt == less_zero_cnt)
					dram_valid = 0;
				if(tx_cnt%frame_size == 0 & tx_cnt!=0) begin
					dram_valid = 0;
					repeat(20) @(posedge clk);
				end				
			end
			if(enc_ready & tx_cnt < less_zero_cnt) begin
				#1;
				dram_valid = 1;
				assert(my_dram_item.randomize() with {
					block_0 dist {0:/10, [1:$]:/90}; 
					block_1 dist {0:/10, [1:$]:/90}; 
					block_2 dist {0:/10, [1:$]:/90}; 
					block_3 dist {0:/10, [1:$]:/90}; 
				});
				dram_data = my_dram_item.send_data();
				if((tx_cnt+1)%frame_size == 0)
					dram_last = 1;
				else
					dram_last = 0;				
			end
		end
		tx_cnt = 0;
		@(posedge clk); 
		#1;
		dram_valid = 0;
		#500;


		while(tx_cnt < half_zero_cnt) begin
			@(posedge clk);
			if(enc_ready&dram_valid) begin
				my_cov.sample();
				tx_queue.push_front(dram_data);
				my_dram_item.print("50% zero");
				tx_cnt++;
				#1;
				dram_last = 0;
				if(tx_cnt == half_zero_cnt)
					dram_valid = 0;
				if(tx_cnt%frame_size == 0 & tx_cnt!=0) begin
					dram_valid = 0;
					repeat(20) @(posedge clk);
				end
			end
			if(enc_ready & tx_cnt < half_zero_cnt) begin
				#1;
				dram_valid = 1;
				assert(my_dram_item.randomize() with {
					block_0 dist {0:/50, [1:$]:/50}; 
					block_1 dist {0:/50, [1:$]:/50}; 
					block_2 dist {0:/50, [1:$]:/50}; 
					block_3 dist {0:/50, [1:$]:/50}; 
				});
				dram_data = my_dram_item.send_data();
				if((tx_cnt+1)%frame_size == 0)
					dram_last = 1;
				else
					dram_last = 0;				
			end
		end
		tx_cnt = 0;
		@(posedge clk); 
		#1;
		dram_valid = 0;
		#500;


		while(tx_cnt < more_zero_cnt) begin
			@(posedge clk);
			if(enc_ready&dram_valid) begin
				my_cov.sample();
				tx_queue.push_front(dram_data);
				my_dram_item.print("90% zero");
				tx_cnt++;
				#1;
				dram_last = 0;
				if(tx_cnt == more_zero_cnt)
					dram_valid = 0;
				if(tx_cnt%frame_size == 0 & tx_cnt!=0) begin
					dram_valid = 0;
					repeat(20) @(posedge clk);
				end				
			end
			if(enc_ready & tx_cnt < more_zero_cnt) begin
				#1;
				dram_valid = 1;
				assert(my_dram_item.randomize() with {
					block_0 dist {0:/90, [1:$]:/10}; 
					block_1 dist {0:/90, [1:$]:/10}; 
					block_2 dist {0:/90, [1:$]:/10}; 
					block_3 dist {0:/90, [1:$]:/10}; 
				});
				dram_data = my_dram_item.send_data();
				if((tx_cnt+1)%frame_size == 0)
					dram_last = 1;
				else
					dram_last = 0;				
			end
		end
		tx_cnt = 0;
		@(posedge clk); 
		#1;
		dram_valid = 0;
		#500;


		$display("tx_data = ",tx_queue.size());
		$display("rx_data = ",rx_queue.size());
		if(rx_queue.size() > tx_queue.size())
			$display("Error: wrong size");

		while(rx_queue.size()!=0) #1;
		$display("Coverage = %0.2f %%", my_cov.get_coverage());
		$finish;


		/*
		forever begin
			@(posedge clk);
			if(rx_queue.size() != 0) begin
				expect_result = tx_queue.pop_back();
				actual_result = rx_queue.pop_back();
				if(expect_result != actual_result) begin
					$display("T=%0t	MISMATCH exp = %h, act = %h",$time, 
					expect_result, actual_result);
					err_cnt = err_cnt + 1;
				end
				//else 
				//	$display("T=%0t	MATCH exp = %h, act = %h",$time, 
				//	expect_result, actual_result);
			end
			else begin
				$display("Error Count = %0d", err_cnt);
				$display("Coverage = %0.2f %%", my_cov.get_coverage());
				$finish;
			end
		end	
		*/
	end



	initial begin
		forever begin
			@(posedge clk);
			if(dec_valid)
			rx_queue.push_front(dec_data);
		end
	end
	
	initial begin
		forever begin
			@(posedge clk);
			if(rx_queue.size() != 0) begin
				expect_result = tx_queue.pop_back();
				actual_result = rx_queue.pop_back();
				if(expect_result != actual_result) begin
					$display("T=%0t	MISMATCH exp = %h, act = %h",$time, 
					expect_result, actual_result);
					err_cnt = err_cnt + 1;
					if(err_cnt > 0) begin
						#100;
						$finish; 
					end
				end
				//else 
				//	$display("T=%0t	MATCH exp = %h, act = %h",$time, 
				//	expect_result, actual_result);
			end
			//else begin
			//	$display("Error Count = %0d", err_cnt);
			//	$display("Coverage = %0.2f %%", my_cov.get_coverage());
			//	$finish;
			//end
		end
	end

endmodule



  
  

