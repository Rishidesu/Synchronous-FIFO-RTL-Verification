IVERILOG ?= iverilog
VVP ?= vvp
GTKWAVE ?= gtkwave
BUILD_DIR := build
SIM := $(BUILD_DIR)/fifo_sim.vvp
.PHONY: all run wave clean
all: run
$(SIM): RTL/sync_fifo.v tb/tb_sync_fifo.sv
	mkdir -p $(BUILD_DIR)
	$(IVERILOG) -Wall -g2012 -s tb_sync_fifo -o $(SIM) $^
run: $(SIM)
	$(VVP) $(SIM) | tee $(BUILD_DIR)/simulation.log
wave: run
	$(GTKWAVE) dump.vcd
clean:
	rm -rf $(BUILD_DIR) dump.vcd
