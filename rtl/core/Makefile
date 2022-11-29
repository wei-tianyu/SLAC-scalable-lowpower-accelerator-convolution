###############################################################################
#   FILE    : 	Makefile   
# Describe	:	makefile for universal test
# Author	: 	Tianyu Wei & Yuang Huang
# Time		: 	2022-10-27
# Version	: 	2.0
# Note		: 	do synthesis with general.tcl file, 
#				be care when do the structural simulation -> the defalut parameter in module must be same as testbench
###############################################################################
# make sim -> run behavioral simulation
# make syn -> run synthesis & structural simulation
# make file_vg -> just run synthesis
# make s_syn -> just run structural simulation
# make clean -> clean all the files
# make nuke -> clean all the files and the synthesis result
# make verdi_sim -> use verdi to see behavioral simulation
# make verdi_syn -> use verdi to see structural simulation
################################################################################
## file list
################################################################################
UTILFILES 	 = ../utils/SPad.sv
UTILFILES 	 = ../utils/shift_reg.sv
PEFILES   	 = PE.sv
# PEFILES   	+= PE_row.sv
# PEFILES   	+= PE_cluster.sv
# GLBFILES  	+= glb_iact.sv
# GLBFILES  	+= glb_psum.sv
# GLBFILES  	+= glb_weight.sv
# GLBFILES  	+= GLB_cluster.sv
# ROUTERFILES  = router_iact.sv
# ROUTERFILES += router_psum.sv
# ROUTERFILES += router_weight.sv
# ROUTERFILES += router_cluster.sv
# COREFILE     = HMNoC_cluster.sv

SIMFILES = $(UTILFILES) $(PEFILES) $(GLBFILES) $(ROUTERFILES) $(COREFILE)
################################################################################
## CONFIGURATION
################################################################################
VCS = SW_VCS=2020.12-SP2-1 vcs -sverilog +vc -Mupdate -line -full64 -kdb -lca -debug_access+all
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v
#########################configure part################################################
# SIMULATION CONFIG -> just need to change this to change the simulation
export SIMFILES
export DESIGN_NAME = PE
export CLOCK_NET_NAME = clk
export RESET_NET_NAME = reset
export CLOCK_PERIOD = 5

# export DONT_TOUCH_NAME_DDC =  PE_row.ddc
# export DONT_TOUCH_NAME = PE_row

# TESTBENCH = ../../testbench/router_cluster_5x5_tb.sv
# HEADERS = $(wildcard *.svh)
#####################configure part end################################################



######################don't need to change the below part############################################

# SYNTHESIS CONFIG
SYN_TCL_FILE = general.tcl
SYNFILES = $(DESIGN_NAME).vg

################################################################################
## RULES
################################################################################

# Default target:
all:	sim
.PHONY: all

# Simulation behavioral##################################
sim:	simv $(ASSEMBLED)
	./simv | tee sim_program_$(DESIGN_NAME).out

simv:	$(HEADERS) $(SIMFILES) $(TESTBENCH)
	$(VCS) $^ -o simv

.PHONY: sim

#use dc_shell to synthesis##################################
file_vg: $(HEADERS) $(SIMFILES) $(SYN_TCL_FILE)
	dc_shell-t -f $(SYN_TCL_FILE) | tee synth_$(DESIGN_NAME).out

#complie the testbench with the structural verilog#######################
syn_simv:	file_vg $(HEADERS) $(SYNFILES) $(TESTBENCH)
	$(VCS) $(HEADERS) $(TESTBENCH) $(SYNFILES) $(LIB) -o syn_simv

s_syn_simv: $(HEADERS) $(SYNFILES) $(TESTBENCH) $(HEADERS)
	$(VCS) $(HEADERS) $(TESTBENCH) $(SYNFILES) $(LIB) -o syn_simv
#run the structural test, get the result#######################
syn:	syn_simv
	./syn_simv | tee syn_program_$(DESIGN_NAME).out

#just do behaviroal simulation##################################
s_syn: s_syn_simv
	./syn_simv | tee syn_program_$(DESIGN_NAME).out

# Debugging using verdi##################################
novas.rc: ../../initialnovas.rc
	sed s/UNIQNAME/$$USER/ ../../initialnovas.rc > novas.rc

#use verdi to see the behavioral test##############################
verdi_sim:	simv novas.rc
	if [[ ! -d /tmp/$${USER}470 ]] ; then mkdir /tmp/$${USER}470 ; fi
	./simv -gui=verdi

#use verdi to see the structural test##############################
verdi_syn:	syn_simv novas.rc
	if [[ ! -d /tmp/$${USER}470 ]] ; then mkdir /tmp/$${USER}470 ; fi
	./syn_simv -gui=verdi


#clean & nuke###################################################
clean:
	rm -rvf simv simv* *.daidir csrc vcs.key program.out \
	syn_simv syn_simv.daidir syn_program_$(DESIGN_NAME).out \
	dve *.vpd *.vcd *.dump ucli.key \
	syn_program_$(DESIGN_NAME).out \
	DVEfiles/ verdi* novas* *fsdb*

nuke:	clean
	rm -rvf *.vg *.rep *.db *.chk *.log *.out *.ddc *.pvl *.syn *.mr *.svf

.PHONY: clean nuke
